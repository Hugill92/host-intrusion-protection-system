#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-FirewallCoreIsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FirewallCoreTimestamp {
  return (Get-Date).ToString('yyyyMMdd_HHmmss')
}

function New-FirewallCoreRunId {
  param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Prefix)
  return ('{0}_{1}' -f $Prefix, (Get-FirewallCoreTimestamp))
}

function Ensure-Directory {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Get-FirewallCoreRunRoot {
  param(
    [Parameter(Mandatory)][ValidateSet('Optimizer','Telemetry','Maintenance')][string]$Module,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RunId,
    [switch]$AllowLocalFallback
  )

  $isAdmin = Test-FirewallCoreIsAdmin

  if ($isAdmin) {
    $root = Join-Path 'C:\ProgramData\FirewallCore' $Module
    $runs = Join-Path $root 'Runs'
    $dir  = Join-Path $runs $RunId
    Ensure-Directory -Path $dir
    return $dir
  }

  if (-not $AllowLocalFallback) {
    throw "Not elevated. Local fallback disabled for module '$Module'."
  }

  $root = Join-Path $env:LOCALAPPDATA ('FirewallCore\{0}' -f $Module)
  $runs = Join-Path $root 'Runs'
  $dir  = Join-Path $runs $RunId
  Ensure-Directory -Path $dir
  return $dir
}

function Write-FirewallCoreJson {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][object]$Object,
    [int]$Depth = 8
  )
  $Object | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-FirewallCoreProcess {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$ArgumentList,
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [Parameter(Mandatory)][string]$StdOutPath,
    [Parameter(Mandatory)][string]$StdErrPath
  )

  Ensure-Directory -Path $WorkingDirectory
  $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru -Wait `
        -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath
  return [pscustomobject]@{ ExitCode = $p.ExitCode; StdOutPath = $StdOutPath; StdErrPath = $StdErrPath }
}

function Write-FirewallCoreEventSafe {
  param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][int]$EventId,
    [Parameter(Mandatory)][ValidateSet('Information','Warning','Error')][string]$Level,
    [Parameter(Mandatory)][string]$Message
  )

  $logName = 'FirewallCore'
  try {
    Write-EventLog -LogName $logName -Source $Provider -EventId $EventId -EntryType $Level -Message $Message
    return
  } catch {
    $fallback = Join-Path 'C:\ProgramData\FirewallCore\Logs' 'V2-Events-Fallback.log'
    try {
      Ensure-Directory -Path (Split-Path -Parent $fallback)
      $line = ('{0} [{1}] {2} {3} {4}' -f (Get-Date).ToString('s'), $Level, $Provider, $EventId, $Message)
      Add-Content -LiteralPath $fallback -Value $line -Encoding UTF8
    } catch { }
  }
}

function Get-FirewallCoreHostInfo {
  return [pscustomobject]@{ ComputerName=$env:COMPUTERNAME; UserName=$env:USERNAME; OSVersion=[Environment]::OSVersion.VersionString; PSVersion=$PSVersionTable.PSVersion.ToString() }
}

Export-ModuleMember -Function *-FirewallCore*
