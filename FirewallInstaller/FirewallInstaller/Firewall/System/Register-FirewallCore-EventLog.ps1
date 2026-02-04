# Register-FirewallCore-EventLog.ps1
# Ensures one dedicated log: FirewallCore
# Ensures all FirewallCore.* sources are bound to that log (repairable)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

$LogName = "FirewallCore"
$Sources = @(
  "FirewallCore-Core",
  "FirewallCore-Pentest",
  "FirewallCore-Notifier"
)

function Get-SourceBoundLog([string]$SourceName) {
  $root = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"
  $logs = Get-ChildItem $root -ErrorAction SilentlyContinue
  foreach ($l in $logs) {
    $p = Join-Path $l.PSPath $SourceName
    if (Test-Path $p) { return $l.PSChildName }
  }
  return $null
}

# Ensure log exists
if (-not [System.Diagnostics.EventLog]::Exists($LogName)) {
  New-EventLog -LogName $LogName -Source $Sources[0]
}

# Ensure each source is bound to FirewallCore (repair if bound elsewhere)
foreach ($s in $Sources) {
  $bound = Get-SourceBoundLog $s
  if ($bound -and $bound -ne $LogName) {
    try { [System.Diagnostics.EventLog]::DeleteEventSource($s) } catch {}
  }
  if (-not [System.Diagnostics.EventLog]::SourceExists($s)) {
    New-EventLog -LogName $LogName -Source $s
  }
}

Write-Host "[OK] FirewallCore Event Log ready (sources bound)"

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBNGa4N5Ao/aPYD
# 405/VqA8E704hPUwKUcskLWSrBuHLKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IBJvXHjB1YBDkeUjrWYIdF0a07vLPkm1yUFtblekw+oCMAsGByqGSM49AgEFAARH
# MEUCIQCkv8hR2M0a48zLIt1ummi7HgR/k7jw3UbtNKSFRuZWSAIgXU1uq5ny6vlz
# Hi68bNCpqoe190zoW5/W4SHJSgEMLto=
# SIG # End signature block
