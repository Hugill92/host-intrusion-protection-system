[CmdletBinding()]
param(
  [string[]] $ViewDirs = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:ProgramData "FirewallCore\User\Views")
  ),
  [string] $Principal = "BUILTIN\Users",
  [string] $Pattern = "FirewallCore*.xml",
  [switch] $Strict
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$m){ Write-Host $m -ForegroundColor Cyan }
function Write-Warn([string]$m){ Write-Host $m -ForegroundColor Yellow }
function Write-Ok([string]$m){ Write-Host $m -ForegroundColor Green }
function Write-Fail([string]$m){ Write-Host $m -ForegroundColor Red }

$anyFail = $false

foreach ($dir in $ViewDirs) {
  Write-Info "=== Ensure ACL: $dir ==="

  if (!(Test-Path -LiteralPath $dir)) {
    Write-Warn "SKIP: missing dir: $dir"
    continue
  }

  $files = Get-ChildItem -LiteralPath $dir -File -Filter $Pattern -ErrorAction Stop
  if (!$files -or $files.Count -eq 0) {
    Write-Warn "No matches for $Pattern in $dir"
    continue
  }

  foreach ($f in $files) {
    try {
      & icacls $f.FullName /grant "${Principal}:(R)" | Out-Null
      Write-Ok ("OK  : {0}" -f $f.Name)
    }
    catch {
      $anyFail = $true
      Write-Fail ("FAIL: {0} :: {1}" -f $f.FullName, $_.Exception.Message)
      if ($Strict) { throw }
    }
  }
}

if ($anyFail -and $Strict) { throw "One or more ACL updates failed." }

if ($anyFail) { Write-Warn "DONE with failures (non-strict)." }
else { Write-Ok "DONE: all ACL updates succeeded." }

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDVgxKJGJlKNeRE
# QZIY1PpEvxPi9+dVzA1S1zMg3BwIoqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IDtKV00gtDG2BPEknduhr/aqZYf9LJrCWAxr6SZzYhBzMAsGByqGSM49AgEFAARH
# MEUCIDlSUP+4zdZhIjrf8rDRXYI90RWWK8/2AIgLe7pwz3+4AiEA5Z2pKXRnAXA8
# wJZs/OVN4bj4RvKlbVj36vxm/wpkvig=
# SIG # End signature block
