Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ProgramRoot  = Join-Path $env:ProgramData "FirewallCore"
$script:QueueRoot    = Join-Path $script:ProgramRoot "NotifyQueue"
$script:QueuePending = Join-Path $script:QueueRoot "Pending"

$script:EventSource  = "FirewallCore"
$script:EventLogName = "FirewallCore"

# ===== Canonical event views (single source of truth) =====
$script:ViewsRoot    = Join-Path $script:ProgramRoot "EventViews"
$script:ViewsMapPath = Join-Path $script:ViewsRoot "EventViewMap.json"
$script:ViewsXmlRoot = Join-Path $script:ViewsRoot "Views"
$script:OpenViewScript = Join-Path $script:ProgramRoot "User\Open-FirewallCoreView.ps1"

function Ensure-Dirs {
    foreach ($d in @(
        $script:ProgramRoot,
        $script:QueueRoot,
        $script:QueuePending,
        $script:ViewsRoot,
        $script:ViewsXmlRoot,
        (Split-Path -Parent $script:OpenViewScript)
    )) {
        if (-not (Test-Path -LiteralPath $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }

    # Keep the click-through Event Viewer opener in a known-good state.
    Ensure-OpenViewScript
}

function Ensure-OpenViewScript {
    # Writes a deterministic, syntax-safe Open-FirewallCoreView.ps1 into ProgramData.
    # This script is called by UI click actions to open Event Viewer to the correct filtered view.
    $content = @'
[CmdletBinding()]
param(
  [ValidateSet('All','Info','Warning','Critical')]
  [string]$Severity = 'All',

  [int]$EventId = 0,

  [int]$SinceMinutes = 240,

  [string]$TestId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogName      = 'FirewallCore'
$CoreRoot     = Join-Path $env:ProgramData 'FirewallCore'
$CoreViewsDir = Join-Path $CoreRoot 'User\Views'
$EvViewsDir   = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'

New-Item -ItemType Directory -Force -Path $CoreViewsDir | Out-Null
New-Item -ItemType Directory -Force -Path $EvViewsDir   | Out-Null

function New-QueryListXml {
  param(
    [Parameter(Mandatory)][string]$Log,
    [Parameter(Mandatory)][string]$Select,
    [Parameter(Mandatory)][string]$OutPath
  )

  $xml = @"
<QueryList>
  <Query Id="0" Path="$Log">
    <Select Path="$Log">$Select</Select>
  </Query>
</QueryList>
"@

  Set-Content -LiteralPath $OutPath -Value $xml -Encoding UTF8 -Force
}

$ms = [int64]$SinceMinutes * 60 * 1000
$timeFilter = "TimeCreated[timediff(@SystemTime) <= $ms]"

# Deterministic selection:
# - If EventId provided: exact match.
# - Else: severity ranges (Info=3000-3999, Warning=4000-4999, Critical=9000-9999).
if ($EventId -gt 0) {
  $select = "*[System[(EventID=$EventId) and $timeFilter]]"
  $name   = "FirewallCore-EventId-$EventId"
} else {
  switch ($Severity) {
    'Info'     { $select = "*[System[(EventID &gt;= 3000) and (EventID &lt;= 3999) and $timeFilter]]"; $name='FirewallCore-Info' }
    'Warning'  { $select = "*[System[(EventID &gt;= 4000) and (EventID &lt;= 4999) and $timeFilter]]"; $name='FirewallCore-Warning' }
    'Critical' { $select = "*[System[(EventID &gt;= 9000) and (EventID &lt;= 9999) and $timeFilter]]"; $name='FirewallCore-Critical' }
    default    { $select = "*[System[$timeFilter]]"; $name='FirewallCore-All' }
  }
}

$coreView = Join-Path $CoreViewsDir ("{0}.xml" -f $name)
$evView   = Join-Path $EvViewsDir   ("{0}.xml" -f $name)

New-QueryListXml -Log $LogName -Select $select -OutPath $coreView
Copy-Item -LiteralPath $coreView -Destination $evView -Force

$eventvwr = Join-Path $env:SystemRoot 'System32\eventvwr.msc'

try {
  Start-Process -FilePath $eventvwr -ArgumentList ("/v:`"$coreView`"") | Out-Null
  return
} catch {
  try {
    Start-Process -FilePath $eventvwr -ArgumentList "`"$coreView`"" | Out-Null
    return
  } catch {
    Start-Process -FilePath $eventvwr -ArgumentList "/c:$LogName" | Out-Null
    return
  }
}
'@
    # Avoid recursion: Ensure-Dirs calls Ensure-OpenViewScript.
    # This helper creates only the minimum directories used by this writer.
    function Ensure-DirsCoreOnly {
        foreach ($d in @((Split-Path -Parent $script:OpenViewScript))) {
            if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        }
    }

    # Ensure-DirsCoreOnly is defined above inside this function; call it now.
    Ensure-DirsCoreOnly

    # Write atomically
    $tmp = "$($script:OpenViewScript).tmp"
    Set-Content -LiteralPath $tmp -Value $content -Encoding UTF8 -Force
    Move-Item -LiteralPath $tmp -Destination $script:OpenViewScript -Force
}

function Ensure-EventSource {
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventSource)) {
            New-EventLog -LogName $script:EventLogName -Source $script:EventSource | Out-Null
        }
    } catch {}
}

# MUST match your current mapping
function New-EventId {
    param([ValidateSet('Info','Warn','Warning','Critical')] [string]$Severity)
    switch ($Severity) {
        'Info'     { 3001 }
        'Warning'  { 4001 }
        'Critical' { 9001 }
        'Warn'     { 4001 }
    }
}

function Write-FirewallEvent {
    param(
        [ValidateSet('Info','Warn','Warning','Critical')] [string]$Severity,
        [string]$Title,
        [string]$Message,
        [string]$TestId
    )

    Ensure-EventSource
    if ($Severity -eq 'Warn') { $Severity = 'Warning' }

    $eid = New-EventId -Severity $Severity
    $etype = switch ($Severity) {
        'Info'     { [System.Diagnostics.EventLogEntryType]::Information }
        'Warning'  { [System.Diagnostics.EventLogEntryType]::Warning }
        'Critical' { [System.Diagnostics.EventLogEntryType]::Error }
    }

    $lines = @($Title, $Message, "Severity=$Severity")
    if ($TestId) { $lines += "TestId=$TestId" }
    $text = ($lines -join "`r`n")

    try {
        Write-EventLog -LogName $script:EventLogName -Source $script:EventSource -EventId $eid -EntryType $etype -Message $text
    } catch {}

    return $eid
}

function Get-FirewallSoundPath {
  param([ValidateSet('Info','Warn','Warning','Critical')] [string]$Severity)
  if ($Severity -eq 'Warn') { $Severity = 'Warning' }
  $base = "C:\Firewall\Monitor\Sounds"
  switch ($Severity) {
    'Info'     { Join-Path $base 'ding.wav' }
    'Warning'  { Join-Path $base 'chimes.wav' }
    'Critical' { Join-Path $base 'chord.wav' }
  }
}

function Get-FirewallTimeoutSeconds {
  param([ValidateSet('Info','Warn','Warning','Critical')] [string]$Severity)
  if ($Severity -eq 'Warn') { $Severity = 'Warning' }
  switch ($Severity) {
    'Info'     { 15 }
    'Warning'  { 30 }
    'Critical' { 0 }
  }
}

function Resolve-FirewallEventView {
    param([int]$EventId)

    if (-not (Test-Path -LiteralPath $script:ViewsMapPath)) { return $null }

    try {
        $map = Get-Content -LiteralPath $script:ViewsMapPath -Raw | ConvertFrom-Json
        $key = [string]$EventId
        if ($map.PSObject.Properties.Name -contains $key) {
            $entry = $map.$key
            return [pscustomobject]@{
                Log     = $entry.Log
                ViewXml = (Join-Path $script:ViewsXmlRoot $entry.View)
            }
        }
    } catch {}

    return $null
}

function New-NotificationPayload {
    param(
        [ValidateSet('Info','Warn','Warning','Critical')] [string]$Severity,
        [string]$Title,
        [string]$Message,
        [int]$EventId,
        [string]$TestId,
        [ValidateSet('Dev','Forced','Pentest','Live')] [string]$Mode = 'Dev',
        [ValidateSet('Toast','Dialog','Both')] [string]$Ux = 'Toast'
    )

    if ($Severity -eq 'Warn') { $Severity = 'Warning' }

    $sound   = Get-FirewallSoundPath -Severity $Severity
    $timeout = Get-FirewallTimeoutSeconds -Severity $Severity
    $view    = Resolve-FirewallEventView -EventId $EventId

    [pscustomobject]@{
        SchemaVer      = 1
        CreatedUtc     = (Get-Date).ToUniversalTime().ToString("o")
        Severity       = $Severity
        Title          = $Title
        Message        = $Message
        EventId        = $EventId
        TestId         = $TestId
        Provider       = 'FirewallCore'
        Mode           = $Mode
        Host           = $env:COMPUTERNAME
        User           = ([Security.Principal.WindowsIdentity]::GetCurrent().Name)

        # Contract
        Ux             = $Ux
        TimeoutSeconds = $timeout
        SoundPath      = $sound

        # Deterministic "open correct view" action (monitor should call this)
        OpenView = @{
            Script = $script:OpenViewScript
            Args   = @{
                EventId       = $EventId
                SinceMinutes  = 240
                TestId        = $TestId
                AlsoOpenEventViewer = $false
            }
        }

        # Optional hints if monitor wants them
        ViewLog        = if ($view) { $view.Log } else { $script:EventLogName }
        ViewXml        = if ($view) { $view.ViewXml } else { $null }
        ViewsRoot      = $script:ViewsRoot
    }
}

function Enqueue-FirewallNotification {
    param([Parameter(Mandatory)] [psobject]$Payload)

    Ensure-Dirs
    $id = [guid]::NewGuid().ToString("n")
    $path = Join-Path $script:QueuePending ("{0}.json" -f $id)
    $Payload | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8 -Force
    return $path
}

function Send-FirewallNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Info','Warn','Warning','Critical')] [string]$Severity,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message,
        [string]$TestId,
        [ValidateSet('Dev','Forced','Pentest','Live')] [string]$Mode = 'Dev',
        [ValidateSet('Toast','Dialog','Both')][string]$Ux
    )

    if ($Severity -eq 'Warn') { $Severity = 'Warning' }

    if (-not $PSBoundParameters.ContainsKey('Ux') -or [string]::IsNullOrWhiteSpace($Ux)) {
      switch ($Severity) {
        'Critical' { $Ux = 'Both' }
        'Warning'  { $Ux = 'Toast' }
        default    { $Ux = 'Toast' }
      }
    }

    $eid = Write-FirewallEvent -Severity $Severity -Title $Title -Message $Message -TestId $TestId
    $payload = New-NotificationPayload -Severity $Severity -Title $Title -Message $Message -EventId $eid -TestId $TestId -Mode $Mode -Ux $Ux
    Enqueue-FirewallNotification -Payload $payload | Out-Null
    return $payload
}

Export-ModuleMember -Function Send-FirewallNotification, Enqueue-FirewallNotification, New-NotificationPayload, Write-FirewallEvent, New-EventId


# SIG # Begin signature block
# MIIFtgYJKoZIhvcNAQcCoIIFpzCCBaMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBsf2hz2w7h9Ju6
# Ku4HqArW5zrI/sftoFTSLRa4sd2z36CCAyAwggMcMIICBKADAgECAhAWqBrNbp/s
# q0LWLpUoGJqsMA0GCSqGSIb3DQEBCwUAMCYxJDAiBgNVBAMMG0ZpcmV3YWxsQ29y
# ZSBTY3JpcHQgU2lnbmluZzAeFw0yNjAxMTExMDMzMDBaFw0zNjAxMTExMDQzMDBa
# MCYxJDAiBgNVBAMMG0ZpcmV3YWxsQ29yZSBTY3JpcHQgU2lnbmluZzCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALanpHAxqchTmDsDelBMMGqhuD/qBCS6
# WBhFkFyipQH1RYozRTLMorh/XyL90qtuHSWc53r1JEwy07Fyeq4VVvpSQpf/kDDx
# fuSpEDKkux9Oqbm0E0fUbCg33kXEPliunM8qnrtz0QKsudVLCSdRc1lzgBNI7vYS
# LoybGQYGSlRKiITXafzKHM3TGp7kxhuc+Fcz1IxTnAd3NRKrUHGfm0p3rflpPL4c
# 8STqXkZCATWtgfkaoCJ6VKbfTn6Plsv54t0rqBmRFfKd5DkmsNrVCdCQk408iBF5
# B9gMtNU+U7Kp9e527JxWcMT5vZaKZ0GhNhYopLJLS+E5CDAtjWH+EgECAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBRo4Db7+Vk/nbKtkGTT9k1im36MhjANBgkqhkiG9w0BAQsFAAOCAQEADoGX2VSj
# mrwdYR7ShaEsj/rtxOBqFDGK1uKMxJAcnjqsD45jhE+fEqMNlvx+Nw7pjxxvLyQd
# zL9JY/hrLgQxdeGCCJyuXxoaOqdDv5UNs9J1UiHd9YitD6Y++GiMCIPNu3JJoUL4
# OmXTs8stDk9jM2m2nbN3vyGOI7SifX+O9cBe6uK/UgiNRQ+D4mSi1A6PsGdPlDcU
# 2QYjt+xT6q6hqgVqgvqWmwrzqkEw1TlQ4d9rVQxmxRH8a2SofdULbbdw6CJJXn4F
# 0Z6fE8KPe1nELXplmRsulgrx1xJJ/mjs7EsVq6tEClQ5Mt0n5RoqxRhfJYGrpo0a
# cEKp1Uw2HG8aQTGCAewwggHoAgEBMDowJjEkMCIGA1UEAwwbRmlyZXdhbGxDb3Jl
# IFNjcmlwdCBTaWduaW5nAhAWqBrNbp/sq0LWLpUoGJqsMA0GCWCGSAFlAwQCAQUA
# oIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcN
# AQkEMSIEIOLia3LnKWRfgdJFNbp5Wdz2m44e4G3yU8LAWj2seIxLMA0GCSqGSIb3
# DQEBAQUABIIBACSWL5jTJil/4LmMgUKEZOSPGt5dK9L5GmIMhIl/vsw1xDngfxps
# V2/xqZ+/1s/YQXItzQBb81Rqag4lpht5CgldspksUDNuePBPqNwAhdHHA9gpDKjT
# w+VaxdTn1gl0XBECtyaTvbXxiyJyDRIdOjsVLRQpAJRm954W4WVYvJlh6NrK+mlQ
# Io12ISdJYtdV9Ea3cJZEguLzSIWwkWuw9ttOxjubF3feb9v5eg07YPACeKzBPq1s
# 7BZR4XzOg5EKjpwjhSZQ7LicS/Ojjkfn28wuWCB41vICXwNF8uhL2STl1GuWQbEI
# n+sZni/OXyF3+R6YdyUosJ5PgEImc+4DV0g=
# SIG # End signature block
