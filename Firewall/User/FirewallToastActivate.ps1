# FirewallToastActivate.ps1 (param-driven, PS5.1-safe)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
  [Parameter(Mandatory=$false)]
  [ValidateSet("ReviewLog","Details","Dialog","EventViewer","OpenEventViewer","")]
  [string] $Action = "",

  [Parameter(Mandatory=$false)]
  [string] $Bundle = "",

  [Parameter(Mandatory=$false)]
  [string] $QueueItem = "",

  [Parameter(Mandatory=$false)]
  [string] $TestId = ""
)

function Write-ToastActivateLog {
  param([string]$Message)
  try {
    $logDir = "C:\ProgramData\FirewallCore\Logs"
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $log = Join-Path $logDir "ToastActivate.log"
    $ts  = (Get-Date).ToString("s")
    Add-Content -LiteralPath $log -Value ("{0} {1}" -f $ts, $Message) -Encoding UTF8
  } catch {}
}

try {
  Write-ToastActivateLog ("ACTION={0} TestId={1} Bundle={2} QueueItem={3}" -f $Action,$TestId,$Bundle,$QueueItem)

  switch ($Action) {
    "ReviewLog" {
      # Prefer generated Open-FirewallCoreView script if present (no console flash)
      $openView = "C:\ProgramData\FirewallCore\User\Open-FirewallCoreView.ps1"
      if (Test-Path -LiteralPath $openView) {
        & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $openView | Out-Null
        Write-ToastActivateLog "REVIEWLOG: invoked Open-FirewallCoreView.ps1"
      } else {
        Write-ToastActivateLog "REVIEWLOG: missing Open-FirewallCoreView.ps1"
      }
    }

    "Details" { goto Dialog }
    "Dialog" {
      $dlg = "C:\Firewall\User\FirewallReviewDialog.ps1"
      if (Test-Path -LiteralPath $dlg) {
        & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $dlg | Out-Null
        Write-ToastActivateLog "DIALOG: invoked FirewallReviewDialog.ps1"
      } else {
        Write-ToastActivateLog "DIALOG: missing FirewallReviewDialog.ps1"
      }
    }

    "EventViewer" { goto OpenEventViewer }
    "OpenEventViewer" {
      Start-Process -FilePath "eventvwr.msc" | Out-Null
      Write-ToastActivateLog "EVENTVIEWER: opened eventvwr.msc"
    }

    default {
      Write-ToastActivateLog ("NOOP: unknown/empty action '{0}'" -f $Action)
    }
  }

} catch {
  Write-ToastActivateLog ("ERROR: {0}" -f $_.Exception.Message)
  exit 1
}

exit 0

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBBUMS/5bZ9Yjf0
# +9m1ENtBKW9FIh+CAdm+q953e0GKDKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggE0MIIBMAIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IHa6ngmWfYsm7nBzesXeo5krZNm/Y6E19OOqesUj8mZhMAsGByqGSM49AgEFAARH
# MEUCIQDLFZsClKWjAijiP+NIaOulus6AUydSTIJ22AtWvz3veQIgNQFmGrOPpPTC
# EGjXoxz71YSS/xvwSxvpgAEOBVIJjsk=
# SIG # End signature block
