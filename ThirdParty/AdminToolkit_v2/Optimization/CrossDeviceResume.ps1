#requires -Version 5.1
<#
.SYNOPSIS
  Enables or disables Cross-Device Resume for the current user (HKCU), optionally also toggling the related Windows feature flag via ViVeTool.

.DESCRIPTION
  - Registry toggle (recommended, supported path): 
      HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration
      IsResumeAllowed = 0 (off) / 1 (on)
  - Optional advanced toggle (UNSUPPORTED by Microsoft): ViVeTool feature id (default 56517033)
      Requires admin, may require reboot, and behavior can vary by Windows build.

.PARAMETER Mode
  Disable or Enable.

.PARAMETER OutputDir
  Folder where logs/backups are written. Defaults to this script folder.

.PARAMETER UseViveTool
  If set, also runs ViVeTool to disable/enable the feature id.

.PARAMETER ViveToolId
  Feature id to toggle (default: 56517033)

.PARAMETER AlsoWriteProgramDataAudit
  If set, also copies the run log bundle into C:\ProgramData\RegistryOptimizations (audit trail).

.NOTES
  PowerShell: 5.1+
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [ValidateSet('Disable','Enable')]
  [string]$Mode = 'Disable',

  [string]$OutputDir = $PSScriptRoot,

  [switch]$UseViveTool,

  [ValidatePattern('^\d+$')]
  [string]$ViveToolId = '56517033',

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

function Get-RegValueOrNull {
  param(
    [Parameter(Mandatory)][string]$KeyPath,
    [Parameter(Mandatory)][string]$Name
  )
  try {
    $o = Get-ItemProperty -LiteralPath $KeyPath -Name $Name -ErrorAction Stop
    return $o.$Name
  } catch { return $null }
}

function Set-RegDword {
  param(
    [Parameter(Mandatory)][string]$KeyPath,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][uint32]$Value
  )
  if (-not (Test-Path -LiteralPath $KeyPath)) {
    if ($PSCmdlet.ShouldProcess($KeyPath, "Create registry key")) {
      New-Item -Path $KeyPath -Force | Out-Null
    }
  }
  if ($PSCmdlet.ShouldProcess("$KeyPath\$Name", "Set DWORD to $Value")) {
    New-ItemProperty -LiteralPath $KeyPath -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
  }
}

# ---- Output folders ----
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Ensure-Dir -Path $OutputDir
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

$LogsDir    = Join-Path $OutputDir 'Logs'
$BackupsDir = Join-Path $OutputDir 'Backups'
Ensure-Dir -Path $LogsDir
Ensure-Dir -Path $BackupsDir

# ---- Registry paths ----
$KeyPs  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
$KeyReg = 'HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
$Name   = 'IsResumeAllowed'
$Desired = if ($Mode -eq 'Disable') { [uint32]0 } else { [uint32]1 }

# ---- Backup key (only if exists) ----
$backupPath = Join-Path $BackupsDir ("XDR_Backup_{0}.reg" -f $stamp)
try {
  $probe = $KeyReg -replace '^HKCU\\', 'HKCU:\'
  if (Test-Path -LiteralPath $probe) {
    if ($PSCmdlet.ShouldProcess($KeyReg, "Export backup to $backupPath")) {
      & reg.exe export $KeyReg $backupPath /y | Out-Null
    }
  }
} catch { }

# ---- Apply registry toggle ----
$pre  = Get-RegValueOrNull -KeyPath $KeyPs -Name $Name
Set-RegDword -KeyPath $KeyPs -Name $Name -Value $Desired
$post = Get-RegValueOrNull -KeyPath $KeyPs -Name $Name

# ---- Optional ViVeTool ----
$vive = [ordered]@{
  attempted = $false
  ok        = $false
  id        = $ViveToolId
  command   = $null
  outputLog = $null
  error     = $null
  rebootRecommended = $false
}

if ($UseViveTool) {
  $vive.attempted = $true

  if (-not (Test-IsAdmin)) {
    $vive.error = 'UseViveTool requested but the session is not elevated (Administrator).'
  } else {
    $vtDir = Join-Path $OutputDir 'Tools\ViveTool'
    $vtExe = Join-Path $vtDir 'ViVeTool.exe'

    $need = @(
      $vtExe,
      (Join-Path $vtDir 'Albacore.ViVe.dll'),
      (Join-Path $vtDir 'Newtonsoft.Json.dll'),
      (Join-Path $vtDir 'FeatureDictionary.pfs')
    )

    $missing = @($need | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missing.Count -gt 0) {
      $vive.error = "ViVeTool bundle missing. Expected files under: $vtDir"
    } else {
      $vive.command = if ($Mode -eq 'Disable') { "/disable /id:$ViveToolId" } else { "/enable /id:$ViveToolId" }
      $vive.outputLog = Join-Path $LogsDir ("CrossDeviceResume_ViveTool_{0}.log" -f $stamp)

      try {
        $out = & $vtExe ($vive.command.Split(' ')) 2>&1 | Out-String
        $out | Out-File -FilePath $vive.outputLog -Encoding UTF8
        $vive.ok = $true
        $vive.rebootRecommended = $true
      } catch {
        $vive.error = $_.Exception.Message
      }
    }
  }
}

# ---- Write "what it does" + JSON run log ----
$whatPath = Join-Path $LogsDir ("CrossDeviceResume_WhatItDoes_{0}.md" -f $stamp)
$jsonPath = Join-Path $LogsDir ("CrossDeviceResume_Run_{0}.json" -f $stamp)

$md = @()
$md += '# Cross-Device Resume Toggle'
$md += ''
$md += ('Timestamp: {0}' -f (Get-Date))
$md += ('Machine: {0}' -f $env:COMPUTERNAME)
$md += ('User: {0}' -f $env:USERNAME)
$md += ''
$md += '## What this changes'
$md += ''
$md += ('- Registry: `{0}\{1}` = **{2}** ({3})' -f $KeyReg, $Name, $Desired, ($Mode.ToUpper()))
$md += '  - 0 = Off'
$md += '  - 1 = On'
$md += ''
$md += '## Why'
$md += ''
$md += '- Disables Cross-Device Resume / cross-device handoff behavior for the current user.'
$md += '- Helpful for iPhone users on Windows who do not use Android cross-device resume features.'
$md += ''
$md += '## Results'
$md += ''
$md += ('- Pre: {0}' -f (if ($null -eq $pre) { '<not set>' } else { $pre }))
$md += ('- Post: {0}' -f (if ($null -eq $post) { '<not set>' } else { $post }))
$md += ('- Backup (if existed): `{0}`' -f $backupPath)
$md += ''

if ($UseViveTool) {
  $md += '## Optional ViVeTool (advanced)'
  $md += ''
  $md += '- ⚠️ This is not an official Microsoft-supported mechanism. Use at your own risk.'
  $md += ('- Attempted: {0}' -f $vive.attempted)
  $md += ('- OK: {0}' -f $vive.ok)
  if ($vive.command)   { $md += ('- Command: `ViVeTool.exe {0}`' -f $vive.command) }
  if ($vive.outputLog) { $md += ('- Output Log: `{0}`' -f $vive.outputLog) }
  if ($vive.error)     { $md += ('- Error: {0}' -f $vive.error) }
  if ($vive.rebootRecommended) { $md += '- Reboot recommended: YES' }
  $md += ''
}

$mdText = ($md -join "`r`n")
$mdText | Out-File -FilePath $whatPath -Encoding UTF8

$runObj = [ordered]@{
  timestamp = (Get-Date).ToString('o')
  machine   = $env:COMPUTERNAME
  user      = $env:USERNAME
  mode      = $Mode
  registry  = [ordered]@{
    key   = $KeyReg
    name  = $Name
    pre   = $pre
    post  = $post
    desired = $Desired
  }
  vivetool  = $vive
  outputs   = [ordered]@{
    whatItDoes = $whatPath
    json       = $jsonPath
    backupsDir = $BackupsDir
    logsDir    = $LogsDir
  }
}

($runObj | ConvertTo-Json -Depth 6) | Out-File -FilePath $jsonPath -Encoding UTF8

if ($AlsoWriteProgramDataAudit) {
  $pd = 'C:\ProgramData\RegistryOptimizations'
  Ensure-Dir -Path $pd
  Copy-Item -LiteralPath $whatPath -Destination $pd -Force
  Copy-Item -LiteralPath $jsonPath -Destination $pd -Force
  if ($vive.outputLog -and (Test-Path -LiteralPath $vive.outputLog)) {
    Copy-Item -LiteralPath $vive.outputLog -Destination $pd -Force
  }
}

Write-Host ''
Write-Host '[OK] Cross-Device Resume toggle complete.'
Write-Host ('  - Registry: {0}\{1} => {2}' -f $KeyReg, $Name, $Desired)
Write-Host ('  - Logs: {0}' -f $LogsDir)
if ($UseViveTool) {
  if ($vive.ok) {
    Write-Host ('  - ViVeTool: OK (id {0})' -f $ViveToolId)
    Write-Host '  - Reboot recommended.'
  } else {
    Write-Host ('  - ViVeTool: NOT OK ({0})' -f $vive.error)
  }
}
