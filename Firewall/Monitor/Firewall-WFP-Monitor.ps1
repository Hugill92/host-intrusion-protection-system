. "C:\Firewall\Modules\WFP-Helpers.ps1"
. "C:\Firewall\Modules\WFP-Actions.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =====================
# PATHS / CONFIG
# =====================
$Root       = "C:\Firewall"
$State      = Join-Path $Root "State"
$Bookmark   = Join-Path $State "wfp.bookmark.json"
$ConfigPath = Join-Path $State "wfp.config.json"
$AllowPath  = Join-Path $State "wfp.allowlist.json"
$StrikePath = Join-Path $State "wfp.strikes.json"
$BlockPath  = Join-Path $State "wfp.blocked.json"
$DenyPath   = Join-Path $State "wfp.denyhash.json"

if (!(Test-Path $ConfigPath)) { throw "Missing $ConfigPath" }
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$eventIds     = @($config.EventIds | ForEach-Object {[int]$_})
$maxEvents    = [int]($config.MaxEventsPerPoll ?? 200)
$alertPerProc = [int]($config.AlertThresholdPerProcessPerPoll ?? 50)
$burstPerPoll = [int]($config.BurstThresholdPerPoll ?? 200)
$enrichMax    = [int]($config.MaxEnrichPerPoll ?? 10)
$correlateMin = [int]($config.CorrelateWindowMinutes ?? 5)
$hashFiles    = [bool]($config.HashExecutables ?? $false)

# =====================
# ALLOWLIST / STATE
# =====================
$allow   = (Test-Path $AllowPath)  ? (Get-Content $AllowPath -Raw | ConvertFrom-Json)  : $null
$strikes = Load-Json $StrikePath
$blocked = Load-Json $BlockPath
$deny    = (Test-Path $DenyPath)   ? (Get-Content $DenyPath -Raw | ConvertFrom-Json)   : $null

$lastId = 0
if (Test-Path $Bookmark) {
    try { $lastId = (Get-Content $Bookmark -Raw | ConvertFrom-Json).LastRecordId } catch {}
}

# =====================
# EVENT SOURCE
# =====================
$src = "Firewall-WFP"
if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
    New-EventLog -LogName Firewall -Source $src
}

# =====================
# HELPERS
# =====================
function Get-EventDataMap($ev){
    $xml = [xml]$ev.ToXml()
    $d = @{}
    foreach ($x in $xml.Event.EventData.Data) {
        if ($x.Name) { $d[$x.Name] = [string]$x.'#text' }
    }
    $d
}

function Parse-Wfp($ev){
    $d = Get-EventDataMap $ev
    [pscustomobject]@{
        RecordId    = $ev.RecordId
        Time        = $ev.TimeCreated
        EventId     = $ev.Id
        Application = ($d["Application"] ?? $d["ApplicationName"])
        Pid         = ($d["ProcessID"] ?? $d["ProcessId"])
        DstAddr     = $d["DestAddress"]
        DstPort     = $d["DestPort"]
        Proto       = $d["Protocol"]
    }
}

function IsNoise($i){
    if (-not $allow) { return $false }
    if ($allow.ProcessNameContains | Where-Object { $i.Application -like "*$_*" }) { return $true }
    if ($allow.DestPorts | Where-Object { $i.DstPort -eq $_ }) { return $true }
    if ($allow.DestAddresses | Where-Object { $i.DstAddr -eq $_ }) { return $true }
    return $false
}

function Get-ProcInfo($pid){
    try {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$pid"
        [pscustomobject]@{
            Exe = $p.ExecutablePath
            Cmd = $p.CommandLine
        }
    } catch { $null }
}

function Get-Sha256($p){
    try { if ($p -and (Test-Path $p)) { (Get-FileHash -Algorithm SHA256 -Path $p).Hash } }
    catch { $null }
}

# =====================
# COLLECT EVENTS
# =====================
$events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=$eventIds} -MaxEvents $maxEvents |
          Where-Object { $_.RecordId -gt $lastId } |
          Sort-Object RecordId

if (-not $events) { goto UpdateBookmark }

$parsed = $events | ForEach-Object { Parse-Wfp $_ }
$signal = $parsed | Where-Object { -not (IsNoise $_) }

$maxId = ($events | Measure-Object RecordId -Maximum).Maximum

# =====================
# BURST ALERT (C1)
# =====================
if ($signal.Count -ge $burstPerPoll) {
    Write-EventLog -LogName Firewall -Source $src -EventId 3410 -EntryType Warning `
        -Message "WFP BURST: signal=$($signal.Count) total=$($parsed.Count)"
}

# =====================
# GROUP + ENRICH
# =====================
$groups = $signal | Group-Object Application | Sort-Object Count -Descending
$enriched = @()

foreach ($g in ($groups | Select-Object -First $enrichMax)) {
    $sample = $signal | Where-Object Application -eq $g.Name | Select-Object -First 1
    $pi = $sample.Pid ? (Get-ProcInfo $sample.Pid) : $null
    $exe = $pi.Exe
    $hash = ($hashFiles) ? (Get-Sha256 $exe) : $null

    $enriched += [pscustomobject]@{
        Process = $g.Name
        Count   = $g.Count
        Pid     = $sample.Pid
        Exe     = $exe
        Hash    = $hash
    }
}

# =====================
# SUMMARY EVENT
# =====================
$summary = "WFP summary: total=$($parsed.Count), signal=$($signal.Count), top=" +
           (($enriched | Select-Object -First 5 | ForEach-Object {"$($_.Process)=$($_.Count)"}) -join ", ")

Write-EventLog -LogName Firewall -Source $src -EventId 3400 -EntryType Information -Message $summary

# =====================
# C2 / C3 ENFORCEMENT
# =====================
$top = $enriched | Select-Object -First 1
if (-not $top) { goto UpdateBookmark }

# Ensure we have a real filesystem path
$exe = $top.Exe
if (-not $exe -or -not (Test-Path $exe)) {
    Write-Warning "C3 skipped: unresolved executable path for process '$($top.Process)'"
    goto UpdateBookmark
}

# =====================
# DENY-HASH (IMMEDIATE C3)
# =====================
if ($deny -and $top.Hash -and ($deny.DenySha256 -contains $top.Hash)) {

    Invoke-PersistentBlock -ExePath $exe

    Write-EventLog `
        -LogName Firewall `
        -Source $src `
        -EventId 3404 `
        -EntryType Error `
        -Message "DENY-HASH BLOCK: exe='$exe' sha256=$($top.Hash)"

    goto UpdateBookmark
}


# C2 TEMP BLOCK
if ($top.Count -ge $alertPerProc) {
    Write-EventLog -LogName Firewall -Source $src -EventId 3401 -EntryType Warning `
        -Message "WFP ALERT (C2): exe='$($top.Exe)' count=$($top.Count)"

    Invoke-TempBlock -ExePath $top.Exe -Minutes 10

    if (-not $strikes.ContainsKey($top.Exe)) {
        $strikes[$top.Exe] = @{ Count = 0 }
    }
    $strikes[$top.Exe].Count++
    $strikes[$top.Exe].LastSeen = (Get-Date).ToString("o")
    Save-Json $strikes $StrikePath
}

# C3 ESCALATION
if ($strikes.ContainsKey($top.Exe) -and $strikes[$top.Exe].Count -ge 3) {
    Invoke-PersistentBlock -ExePath $top.Exe
    Write-EventLog -LogName Firewall -Source $src -EventId 3402 -EntryType Error `
        -Message "C3 PERSISTENT BLOCK: exe='$($top.Exe)'"
    $blocked[$top.Exe] = @{ BlockedAt=(Get-Date).ToString("o"); Mode="C3" }
    Save-Json $blocked $BlockPath
}

# =====================
# BOOKMARK
# =====================
UpdateBookmark:
@{ LastRecordId=$maxId; Updated=(Get-Date).ToString("o") } |
    ConvertTo-Json | Set-Content $Bookmark -Encoding UTF8
