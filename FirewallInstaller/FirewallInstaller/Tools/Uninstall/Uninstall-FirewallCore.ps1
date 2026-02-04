<# 
.SYNOPSIS
  FirewallCore canonical uninstall engine (Default + Clean).

.DESCRIPTION
  Default uninstall removes FirewallCore components but preserves logs/evidence.
  Clean uninstall removes everything, including ProgramData, as the final step.

  Contracts:
  - PS5.1-compatible (no PS7 syntax)
  - AllSigned-friendly (no runtime edits)
  - Deterministic Event Log + durable file logs
  - Idempotent (repeat runs are NOOP and must not error)

.PARAMETER Mode
  Default or Clean

.PARAMETER ForceClean
  Required to execute clean uninstall.

.NOTES
  Event Log: FirewallCore
  Source:   FirewallCore-Installer
  Default IDs: 2000 START, 2008 OK, 2003 NOOP, 2901 FAIL
  Clean IDs:   2100 START, 2108 OK, 2103 NOOP, 2901 FAIL
#>

[CmdletBinding()]
param(
  [ValidateSet('Default','Clean')]
  [string]$Mode = 'Default',

  [switch]$ForceClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------
# Constants / Contracts
# -----------------------------
$EventLogName = 'FirewallCore'
$EventSource  = 'FirewallCore-Installer'

$Id_UninstallStart = 2000
$Id_UninstallOk    = 2008
$Id_UninstallNoop  = 2003

$Id_CleanStart = 2100
$Id_CleanOk    = 2108
$Id_CleanNoop  = 2103

$Id_Fail = 2901

$TaskNames = @(
  'Firewall-Defender-Integration',
  'FirewallCore Toast Listener',
  'FirewallCore Toast Watchdog',
  'FirewallCore User Notifier',
  'FirewallCore-ToastListener'
)

$OwnedRuleGroups = @('FirewallCorev1','FirewallCorev2','FirewallCorev3')

$FirewallRoot   = 'C:\Firewall'
$ProgramDataRoot= 'C:\ProgramData\FirewallCore'

$LogsDir = Join-Path $ProgramDataRoot 'Logs'

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-EventSource {
  try {
    if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
      # NOTE: Creating event source may require admin; fail softly into file log.
      [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
    }
  } catch {}
}

function Write-FwEvent {
  param(
    [Parameter(Mandatory)][int]$Id,
    [Parameter(Mandatory)][string]$Message
  )
  try {
    Ensure-EventSource
    Write-EventLog -LogName $EventLogName -Source $EventSource -EventId $Id -EntryType Information -Message $Message
  } catch {
    # Best-effort only; file log is the durable channel
  }
}

function New-RunLogPath {
  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  if ($Mode -eq 'Clean') {
    return Join-Path $LogsDir ("Uninstall-FirewallCore_CLEAN_{0}.log" -f $ts)
  }
  return Join-Path $LogsDir ("Uninstall-FirewallCore_{0}.log" -f $ts)
}

$RunLogPath = $null

function Ensure-LogsDir {
  try {
    if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null }
  } catch {}
}

function Write-RunLog {
  param([Parameter(Mandatory)][string]$Line)
  try {
    if (-not $RunLogPath) { return }
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ("[{0}] {1}" -f $stamp, $Line) | Add-Content -Path $RunLogPath -Encoding UTF8
  } catch {}
}

function Start-TranscriptSafe {
  param([Parameter(Mandatory)][string]$Path)
  try {
    Start-Transcript -Path $Path -Append | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Stop-TranscriptSafe {
  try { Stop-Transcript | Out-Null } catch {}
}

function Remove-TaskIfPresent {
  param([Parameter(Mandatory)][string]$TaskName)
  try {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($t) {
      Write-RunLog ("TASK remove: {0}" -f $TaskName)
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop | Out-Null
    } else {
      Write-RunLog ("TASK noop: {0} (not found)" -f $TaskName)
    }
  } catch {
    Write-RunLog ("TASK fail: {0} :: {1}" -f $TaskName, $_.Exception.Message)
  }
}

function Remove-OwnedFirewallRules {
  foreach ($g in $OwnedRuleGroups) {
    try {
      $rules = Get-NetFirewallRule -Group $g -ErrorAction SilentlyContinue
      if ($rules) {
        Write-RunLog ("FW rules remove group: {0} (count={1})" -f $g, @($rules).Count)
        $rules | Remove-NetFirewallRule -ErrorAction Stop
      } else {
        Write-RunLog ("FW rules noop group: {0} (none)" -f $g)
      }
    } catch {
      Write-RunLog ("FW rules fail group: {0} :: {1}" -f $g, $_.Exception.Message)
    }
  }
}

function Remove-PathIfPresent {
  param([Parameter(Mandatory)][string]$Path)
  try {
    if (Test-Path $Path) {
      Write-RunLog ("PATH remove: {0}" -f $Path)
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    } else {
      Write-RunLog ("PATH noop: {0} (not found)" -f $Path)
    }
  } catch {
    Write-RunLog ("PATH fail: {0} :: {1}" -f $Path, $_.Exception.Message)
  }
}

function Test-FirewallCoreInstalled {
  # Deterministic heuristic: any of these indicates an install footprint
  if (Test-Path $FirewallRoot) { return $true }
  if (Test-Path $ProgramDataRoot) { return $true }

  foreach ($name in $TaskNames) {
    try { if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) { return $true } } catch {}
  }

  foreach ($g in $OwnedRuleGroups) {
    try { if (Get-NetFirewallRule -Group $g -ErrorAction SilentlyContinue) { return $true } } catch {}
  }

  return $false
}

function Restore-PreInstallBaseline {
  # TODO (Codex): Implement PRE baseline discovery + import.
  # Requirements:
  # - If PRE baseline exists: restore deterministically (import .wfw or equivalent)
  # - Then export POST-uninstall artifacts (.wfw + .json + .thc if used) and hash via existing tamper hashing logic.
  # - If PRE baseline missing: explicit fallback behavior, clearly logged (do not silently destroy unrelated rules).
  Write-RunLog "BASELINE restore: TODO (not implemented yet)"
}

# -----------------------------
# Main
# -----------------------------
if (-not (Test-IsAdmin)) {
  throw "UNINSTALL requires elevation (run as Administrator)."
}

Ensure-LogsDir
$RunLogPath = New-RunLogPath

Write-RunLog ("BEGIN mode={0} user={1} computer={2} admin={3}" -f $Mode, $env:USERNAME, $env:COMPUTERNAME, (Test-IsAdmin))
$transcriptStarted = Start-TranscriptSafe -Path $RunLogPath

try {
  if ($Mode -eq 'Clean' -and -not $ForceClean) {
    Write-RunLog "CLEAN gate: missing -ForceClean => NOOP"
    Write-FwEvent -Id $Id_CleanNoop -Message "CLEAN UNINSTALL NOOP | reason=missing-forceclean"
    return
  }

  if (-not (Test-FirewallCoreInstalled)) {
    if ($Mode -eq 'Clean') {
      Write-RunLog "Not installed => CLEAN NOOP"
      Write-FwEvent -Id $Id_CleanNoop -Message "CLEAN UNINSTALL NOOP | reason=not-installed"
    } else {
      Write-RunLog "Not installed => UNINSTALL NOOP"
      Write-FwEvent -Id $Id_UninstallNoop -Message "UNINSTALL NOOP | reason=not-installed"
    }
    return
  }

  if ($Mode -eq 'Clean') {
    Write-FwEvent -Id $Id_CleanStart -Message "CLEAN UNINSTALL START"
    Write-RunLog "CLEAN UNINSTALL START"
  } else {
    Write-FwEvent -Id $Id_UninstallStart -Message "UNINSTALL START"
    Write-RunLog "UNINSTALL START"
  }

  # 1) Remove scheduled tasks
  foreach ($t in $TaskNames) { Remove-TaskIfPresent -TaskName $t }

  # 2) Remove owned firewall rules
  Remove-OwnedFirewallRules

  # 3) Restore firewall baseline (PRE) (preferred)
  Restore-PreInstallBaseline

  # 4) Remove install footprints (Default removes product folders but preserves evidence)
  # NOTE: Default uninstall must preserve ProgramData logs/evidence.
  if ($Mode -eq 'Clean') {
    # Clean uninstall removes everything, but ProgramData purge must be LAST.
    Remove-PathIfPresent -Path $FirewallRoot

    # TODO (Codex): remove wrappers/protocol handlers/shortcuts if present
    Write-RunLog "WRAPPERS/handlers removal: TODO"

    # LAST: ProgramData purge (including logs)
    Write-RunLog "CLEAN purge ordering: ProgramData removal is LAST"
    Remove-PathIfPresent -Path $ProgramDataRoot

    Write-FwEvent -Id $Id_CleanOk -Message "CLEAN UNINSTALL OK"
    Write-RunLog "CLEAN UNINSTALL OK"
  } else {
    # Default uninstall: remove product folder(s), preserve ProgramData evidence
    Remove-PathIfPresent -Path $FirewallRoot

    # TODO (Codex): remove wrappers/protocol handlers/shortcuts if present
    Write-RunLog "WRAPPERS/handlers removal: TODO"

    Write-FwEvent -Id $Id_UninstallOk -Message "UNINSTALL OK"
    Write-RunLog "UNINSTALL OK"
  }

} catch {
  $msg = $_.Exception.Message
  Write-RunLog ("FAIL :: {0}" -f $msg)

  if ($Mode -eq 'Clean') {
    Write-FwEvent -Id $Id_Fail -Message ("CLEAN UNINSTALL FAIL | {0}" -f $msg)
  } else {
    Write-FwEvent -Id $Id_Fail -Message ("UNINSTALL FAIL | {0}" -f $msg)
  }

  throw
} finally {
  if ($transcriptStarted) { Stop-TranscriptSafe }
  Write-RunLog "END"
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBWz97Q9BqVP59V
# iMCld9qcfZBVpP+zaV1o/B09BATpaaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggE1MIIBMQIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IDrJV6/0djGcfJ5RsZdgLtvvYao14/TV0eambXXThWpxMAsGByqGSM49AgEFAARI
# MEYCIQC9XAcelf3bKEAlXOhtcfVZMJsS5SMsf1OnXMZXWD9/hAIhAK+jIGEkCOaO
# OtiGpg3o0O1x2BJPjvKdFp3IUhFhguxO
# SIG # End signature block
