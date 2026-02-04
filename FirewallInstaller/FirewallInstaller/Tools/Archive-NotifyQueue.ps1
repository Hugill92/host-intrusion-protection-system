[CmdletBinding()]
param(
  [string]$QueueDir    = 'C:\ProgramData\FirewallCore\NotifyQueue',
  [string]$ArchiveRoot = 'C:\ProgramData\FirewallCore\NotifyQueue_Archive',
  [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    $null = New-Item -ItemType Directory -Path $p -Force
  }
}

function Log([string]$msg) {
  $logDir = 'C:\ProgramData\FirewallCore\Logs'
  Ensure-Dir $logDir
  $log = Join-Path $logDir 'NotifyQueue-Archive.log'
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
  Add-Content -LiteralPath $log -Value ("{0} {1}" -f $ts, $msg)
}

Ensure-Dir $ArchiveRoot

if (-not (Test-Path -LiteralPath $QueueDir)) {
  Log ("QueueDir missing, nothing to archive: {0}" -f $QueueDir)
  Write-Host ("[WARN] QueueDir missing: {0}" -f $QueueDir)
  return
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dest = Join-Path $ArchiveRoot ("ARCHIVE_{0}" -f $stamp)
Ensure-Dir $dest

$items = Get-ChildItem -LiteralPath $QueueDir -Force -ErrorAction SilentlyContinue
if (-not $items) {
  Log ("Queue empty, nothing to archive: {0}" -f $QueueDir)
  Write-Host ("[OK] Queue empty: {0}" -f $QueueDir)
  return
}

$cnt = 0
foreach ($it in $items) {
  try {
    $target = Join-Path $dest $it.Name
    Move-Item -LiteralPath $it.FullName -Destination $target -Force
    $cnt++
  } catch {
    Log ("ERROR moving {0}: {1}" -f $it.FullName, $_.Exception.Message)
    Write-Warning ("Failed to move {0}" -f $it.FullName)
  }
}

Log ("Archived {0} item(s) from {1} to {2}" -f $cnt, $QueueDir, $dest)
Write-Host ("[OK] Archived {0} item(s) -> {1}" -f $cnt, $dest)

if ($PassThru) {
  [pscustomobject]@{
    QueueDir   = $QueueDir
    ArchiveDir = $dest
    Count      = $cnt
  }
}
# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDX/zSGx9Twy/Ki
# KigOe1md+8de8HpzSzlhP1p16Gd5saCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IDONOa77P7LskNGJ1e3QlcnhR5buSLPPozcTjliAsCqmMAsGByqGSM49AgEFAARI
# MEYCIQCIyqywznyaGMT0770/5T3GC/cy2aPybXxI4gKljrvsKgIhANAoys8UT+mZ
# NGy4KraxccWFTZv4GEBl747AJbd3d1nA
# SIG # End signature block
