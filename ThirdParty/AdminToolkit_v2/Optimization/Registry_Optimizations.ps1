#requires -Version 5.1
<#
.SYNOPSIS
  Applies a small, explicit set of registry performance optimizations and writes an audit log bundle.

.DESCRIPTION
  - Safe, explicit callouts only (no "extra" tweaks)
  - Creates per-run backups (.reg exports) of only the keys touched
  - Writes a human-readable "what each tweak does" file + JSON run log
  - Supports -WhatIf (ShouldProcess)

.PARAMETER OutputDir
  Folder where logs/backups are written. Defaults to the folder containing this script.

.PARAMETER AlsoWriteProgramDataAudit
  If set, also copies the run log bundle into C:\ProgramData\RegistryOptimizations (audit trail).

.NOTES
  Requires: Administrator
  PowerShell: 5.1+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [string]$OutputDir = $PSScriptRoot,

  # Optional: Cross-Device Resume toggle (Phone Link resume / cross-device handoff).
  # Recommended only if you do NOT use Android cross-device resume features.
  [switch]$IncludeCrossDeviceResume,

  [switch]$AlsoWriteProgramDataAudit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Dir {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
  }
}

function To-UInt32 {
  param([Parameter(Mandatory)][object]$Value)
  if ($null -eq $Value) { return $null }
  try { return [uint32]$Value } catch { }
  return [uint32]([int32]$Value)
}

function Convert-ToUInt32 {
  param([Parameter(Mandatory)][object]$Value)

  if ($null -eq $Value) { return $null }
  if ($Value -is [uint32]) { return $Value }
  if ($Value -is [int] -or $Value -is [long]) { return [uint32]$Value }

  $s = ([string]$Value).Trim()
  if ($s -match '^0x[0-9a-fA-F]+$') { return [uint32]::Parse($s.Substring(2), 'HexNumber') }
  if ($s -match '^[0-9a-fA-F]{8}$') { return [uint32]::Parse($s, 'HexNumber') }
  if ($s -match '^\d+$') { return [uint32]$s }

  throw "Cannot convert to UInt32: '$Value'"
}

function To-DwordHex {
  param([Parameter(Mandatory)][object]$Value)
  if ($null -eq $Value) { return $null }
  return ('0x{0:X8}' -f (To-UInt32 $Value))
}

function Ensure-RegKey {
  param([Parameter(Mandatory)][string]$KeyPath)
  if (-not (Test-Path -LiteralPath $KeyPath)) {
    if ($PSCmdlet.ShouldProcess($KeyPath, "Create registry key")) {
      New-Item -Path $KeyPath -Force | Out-Null
    }
  }
}

function Get-RegValueOrNull {
  param(
    [Parameter(Mandatory)][string]$KeyPath,
    [Parameter(Mandatory)][string]$Name
  )
  try {
    $o = Get-ItemProperty -LiteralPath $KeyPath -Name $Name -ErrorAction Stop
    return $o.$Name
  } catch {
    return $null
  }
}

function Set-RegValueDeterministic {
  param(
    [Parameter(Mandatory)][string]$KeyPath,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ValidateSet('DWord','String')][string]$Type,
    [Parameter(Mandatory)][object]$Value
  )

  Ensure-RegKey -KeyPath $KeyPath

  if ($Type -eq 'DWord') {
    $dw = Convert-ToUInt32 -Value $Value
    if ($PSCmdlet.ShouldProcess("$KeyPath\$Name", "Set DWORD to $($dw) / $(To-DwordHex $dw)")) {
      New-ItemProperty -LiteralPath $KeyPath -Name $Name -Value ([uint32]$dw) -PropertyType DWord -Force | Out-Null
    }
  } else {
    if ($PSCmdlet.ShouldProcess("$KeyPath\$Name", "Set String to '$Value'")) {
      New-ItemProperty -LiteralPath $KeyPath -Name $Name -Value ([string]$Value) -PropertyType String -Force | Out-Null
    }
  }
}

function Backup-RegKeyIfExists {
  param(
    [Parameter(Mandatory)][string]$RegExePath, # e.g. HKLM\SOFTWARE\...
    [Parameter(Mandatory)][string]$OutFile
  )

  $probe = $RegExePath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
  if (-not (Test-Path -LiteralPath $probe)) { return }

  if ($PSCmdlet.ShouldProcess($RegExePath, "Export backup to $OutFile")) {
    & reg.exe export $RegExePath $OutFile /y | Out-Null
  }
}

if (-not (Test-IsAdmin)) {
  throw "Please run this script in an elevated (Administrator) PowerShell session."
}

# ---- Output folders ----
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Ensure-Dir -Path $OutputDir
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

$LogsDir    = Join-Path $OutputDir 'Logs'
$BackupsDir = Join-Path $OutputDir 'Backups'

Ensure-Dir -Path $LogsDir
Ensure-Dir -Path $BackupsDir

$RunJsonPath = Join-Path $LogsDir "RegistryOptimization_Run_$stamp.json"
$WhatMdPath  = Join-Path $LogsDir "RegistryOptimization_WhatItDoes_$stamp.md"
$ReportPath  = Join-Path $LogsDir "RegistryOptimization_Report_$stamp.txt"

# ---- Catalog (explicit callouts only) ----
$kSystemProfile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$kControl       = 'HKLM:\SYSTEM\CurrentControlSet\Control'
$kPriority      = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
$kGamesTask     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
$kPowerKey      = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583'
$kCrossDevice  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'

$Catalog = @(
  @{
    Id='MM-01'; Category='Multimedia/SystemProfile'
    Key=$kSystemProfile; Name='NetworkThrottlingIndex'; Type='DWord'; Desired='FFFFFFFF'
    Meaning='Disables network throttling behavior used by the multimedia scheduler (sets to 0xFFFFFFFF).'
    Notes='Common latency/perf tweak. Applied as DWORD -1 / 0xFFFFFFFF.'
    Backup='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
  },
  @{
    Id='MM-02'; Category='Multimedia/SystemProfile'
    Key=$kSystemProfile; Name='SystemResponsiveness'; Type='DWord'; Desired='0'
    Meaning='Reduces the percentage of CPU reserved for background tasks by the multimedia scheduler.'
    Notes='Often used alongside NetworkThrottlingIndex for responsiveness.'
    Backup='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
  },
  @{
    Id='SV-01'; Category='Services'
    Key=$kControl; Name='SvcHostSplitThresholdInKB'; Type='DWord'; Desired='1000000'
    Meaning='Adjusts the memory threshold that controls svchost service grouping/splitting.'
    Notes='Set to 0x001000000 (~1,048,576 KB).'
    Backup='HKLM\SYSTEM\CurrentControlSet\Control'
  },
  @{
    Id='CPU-01'; Category='PriorityControl'
    Key=$kPriority; Name='Win32PrioritySeparation'; Type='DWord'; Desired='38'
    Meaning='Tweaks foreground/background thread quantum and priority separation.'
    Notes='Value 38 (0x00000026) is a commonly used interactive/foreground bias setting.'
    Backup='HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl'
  },
  @{
    Id='GM-01'; Category='Games Task Profile'
    Key=$kGamesTask; Name='GPU Priority'; Type='DWord'; Desired='8'
    Meaning='Sets GPU scheduling priority for the Games multimedia task profile.'
    Notes='Only the requested Games profile values are touched.'
    Backup='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
  },
  @{
    Id='GM-02'; Category='Games Task Profile'
    Key=$kGamesTask; Name='Priority'; Type='DWord'; Desired='2'
    Meaning='Sets base task scheduling priority for the Games multimedia task profile.'
    Notes='Pairs with Scheduling Category/SFIO Priority below.'
    Backup='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
  },
  @{
    Id='GM-03'; Category='Games Task Profile'
    Key=$kGamesTask; Name='Scheduling Category'; Type='String'; Desired='High'
    Meaning='Sets the scheduling category for the Games multimedia task profile.'
    Notes='String value.'
    Backup='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
  },
  @{
    Id='GM-04'; Category='Games Task Profile'
    Key=$kGamesTask; Name='SFIO Priority'; Type='String'; Desired='High'
    Meaning='Sets the Storage I/O priority (SFIO) for the Games multimedia task profile.'
    Notes='String value.'
    Backup='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
  },
  @{
    Id='PW-01'; Category='Power Setting Subkey'
    Key=$kPowerKey; Name='ValueMax'; Type='DWord'; Desired='0'
    Meaning='Sets ValueMax=0 for the specified power setting subkey.'
    Notes='This script does NOT modify "Attributes".'
    Backup='HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583'
  }
)

# ---- Optional: Cross-Device Resume (Current User) ----
if ($IncludeCrossDeviceResume) {
  $Catalog += @(
    @{
      Id='XDR-01'; Category='Cross-Device Resume'
      Key=$kCrossDevice; Name='IsResumeAllowed'; Type='DWord'; Desired='0'
      Meaning='Disables Cross-Device Resume (cross-device handoff / Phone Link resume) for the current user.'
      Notes='Recommended if you do NOT use Android cross-device resume features. Set to 1 to re-enable.'
      Backup='HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
    }
  )
}

# ---- Backups (only the keys touched) ----
$uniqueBackups = @($Catalog | ForEach-Object { $_.Backup } | Select-Object -Unique)
$bi = 0
foreach ($b in $uniqueBackups) {
  $bi++
  $fn = ('{0:D2}_{1}_{2}.reg' -f $bi, ($b -replace '[\\: ]','_'), $stamp)
  Backup-RegKeyIfExists -RegExePath $b -OutFile (Join-Path $BackupsDir $fn)
}

# ---- Apply + capture pre/post ----
$run = New-Object System.Collections.Generic.List[object]
foreach ($t in $Catalog) {
  $pre  = Get-RegValueOrNull -KeyPath $t.Key -Name $t.Name

  Set-RegValueDeterministic -KeyPath $t.Key -Name $t.Name -Type $t.Type -Value $t.Desired

  $post = Get-RegValueOrNull -KeyPath $t.Key -Name $t.Name

  $preText  = if ($t.Type -eq 'DWord') { if ($null -eq $pre) { $null } else { (To-DwordHex $pre) } } else { if ($null -eq $pre) { $null } else { [string]$pre } }
  $postText = if ($t.Type -eq 'DWord') { if ($null -eq $post){ $null } else { (To-DwordHex $post) } } else { if ($null -eq $post){ $null } else { [string]$post } }

  $desiredText = if ($t.Type -eq 'DWord') { (To-DwordHex (Convert-ToUInt32 $t.Desired)) } else { [string]$t.Desired }

  $ok = $false
  if ($t.Type -eq 'DWord') {
    $ok = ([uint32](To-UInt32 $post) -eq [uint32](Convert-ToUInt32 $t.Desired))
  } else {
    $ok = ([string]$post -eq [string]$t.Desired)
  }

  $run.Add([pscustomobject]@{
    Id=$t.Id; Category=$t.Category; Key=$t.Key; Name=$t.Name; Type=$t.Type
    Desired=$desiredText; Pre=$preText; Post=$postText; Status= $(if($ok){'OK'}else{'MISMATCH'})
    Meaning=$t.Meaning; Notes=$t.Notes
  }) | Out-Null
}

# ---- Write artifacts (OutputDir) ----
$meta = [pscustomobject]@{
  tool='RegistryOptimizations'
  timestamp=(Get-Date).ToString('s')
  machine=$env:COMPUTERNAME
  user=$env:USERNAME
  psVersion=($PSVersionTable.PSVersion.ToString())
  whatIf=$WhatIfPreference
  outputDir=$OutputDir
  logsDir=$LogsDir
  backupsDir=$BackupsDir
}

$bundle = [pscustomobject]@{
  meta=$meta
  items=$run
}

$bundle | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $RunJsonPath -Encoding UTF8

# Human-readable report (txt)
$txt = New-Object System.Collections.Generic.List[string]
$txt.Add("Registry Optimization Report")
$txt.Add("Timestamp : $($meta.timestamp)")
$txt.Add("Machine   : $($meta.machine)")
$txt.Add("User      : $($meta.user)")
$txt.Add("PS        : $($meta.psVersion)")
$txt.Add("WhatIf    : $($meta.whatIf)")
$txt.Add("")
$txt.Add("Backups   : $BackupsDir")
$txt.Add("JSON Run  : $RunJsonPath")
$txt.Add("")
$txt.Add("Applied values (post-state):")
$txt.Add("")

foreach ($i in $run) {
  $preVal  = if ($null -eq $i.Pre  -or [string]::IsNullOrWhiteSpace([string]$i.Pre))  { '<missing>' } else { [string]$i.Pre }
  $postVal = if ($null -eq $i.Post -or [string]::IsNullOrWhiteSpace([string]$i.Post)) { '<missing>' } else { [string]$i.Post }
  $txt.Add(("[{0}] {1}\{2} | Desired={3} | Pre={4} | Post={5}" -f $i.Status, $i.Key, $i.Name, $i.Desired, $preVal, $postVal))
}

$txt.Add("")

$txt.Add("Non-changes explicitly respected:")
$txt.Add("- Games key: did NOT set Affinity, Background Only, or Clock Rate.")
$txt.Add("- PowerSettings key: did NOT set Attributes.")
$txt.Add("")

$txt | Set-Content -LiteralPath $ReportPath -Encoding UTF8
# "What it does" markdown
$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Registry Optimizations – What Each Tweak Does")
$md.Add("")
$md.Add("*Run Timestamp:* **$($meta.timestamp)**  ")
$md.Add("*Machine:* **$($meta.machine)**  ")
$md.Add("*User:* **$($meta.user)**  ")
$md.Add("")
$md.Add("## Changes Included (Explicit Callouts Only)")
$md.Add("")
$md.Add("| ID | Area | Registry Path | Value | Type | Target | What it does |")
$md.Add("|---:|---|---|---|---|---|---|")

foreach ($t in $Catalog) {
  $target = if ($t.Type -eq 'DWord') { (To-DwordHex (Convert-ToUInt32 $t.Desired)) } else { [string]$t.Desired }
  $path = ('{0}\{1}' -f $t.Key, $t.Name)
  $md.Add(('| {0} | {1} | `{2}` | `{3}` | {4} | `{5}` | {6} |' -f $t.Id, $t.Category, $t.Key, $t.Name, $t.Type, $target, ($t.Meaning -replace '\|','/')))
}

$md.Add("")
$md.Add("## Notes")
$md.Add("- A reboot is recommended after applying these changes.")
$md.Add("- Backups are exported as `.reg` files in `Backups\\` (only the keys touched).")
$md.Add("- This package intentionally avoids additional/unsupported tweaks.")
$md.Add("")

$md | Set-Content -LiteralPath $WhatMdPath -Encoding UTF8

# Optional ProgramData audit copy
if ($AlsoWriteProgramDataAudit) {
  $pd = 'C:\ProgramData\RegistryOptimizations'
  Ensure-Dir -Path $pd
  Copy-Item -LiteralPath $RunJsonPath -Destination $pd -Force
  Copy-Item -LiteralPath $WhatMdPath  -Destination $pd -Force
  Copy-Item -LiteralPath $ReportPath  -Destination $pd -Force
}

Write-Host ""
Write-Host "✅ Registry optimizations completed." -ForegroundColor Green
Write-Host "📁 OutputDir : $OutputDir" -ForegroundColor Green
Write-Host "🧾 Report    : $ReportPath" -ForegroundColor Green
Write-Host "🧩 WhatItDoes: $WhatMdPath" -ForegroundColor Green
Write-Host "🧱 Backups   : $BackupsDir" -ForegroundColor Green
Write-Host "🔎 JSON Run  : $RunJsonPath" -ForegroundColor Green
Write-Host ""
Write-Host "ℹ️ Reboot recommended for full effect." -ForegroundColor Yellow
