[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$NameRegex = '^View_\d+$',

  [string[]]$Roots = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Event Viewer\Views")
  ),

  [string]$ArchiveRoot = (Join-Path $env:ProgramData ("FirewallCore\Logs\ViewArchive\{0:yyyyMMdd_HHmmss}" -f (Get-Date)))
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Path $ArchiveRoot -Force | Out-Null
Write-Host "Archive: $ArchiveRoot" -ForegroundColor DarkGray

$deleted = 0
$kept    = 0

foreach ($root in $Roots) {
  if (!(Test-Path -LiteralPath $root)) { continue }

  Write-Host "`nSCAN: $root" -ForegroundColor Cyan
  $xmls = Get-ChildItem -LiteralPath $root -File -Filter *.xml -ErrorAction SilentlyContinue
  foreach ($f in $xmls) {
    $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (!$raw) { $kept++; continue }

    # Match either Name or DisplayName
    $m1 = [regex]::Match($raw, '<Name>\s*([^<]+)\s*</Name>', 'IgnoreCase')
    $m2 = [regex]::Match($raw, '<DisplayName>\s*([^<]+)\s*</DisplayName>', 'IgnoreCase')

    $name = $null
    if ($m2.Success) { $name = $m2.Groups[1].Value.Trim() }
    elseif ($m1.Success) { $name = $m1.Groups[1].Value.Trim() }

    if ($name -and ($name -match $NameRegex)) {
      $dest = Join-Path $ArchiveRoot $f.Name
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force

      if ($PSCmdlet.ShouldProcess($f.FullName, "Delete custom view '$name'")) {
        Remove-Item -LiteralPath $f.FullName -Force
        Write-Host "DELETE: $name  ($($f.Name))" -ForegroundColor Yellow
        $deleted++
      }
    } else {
      $kept++
    }
  }
}

Write-Host "`nDONE. Deleted: $deleted  Kept: $kept" -ForegroundColor Green

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBPYzPaCkJ6MS7w
# poDD8mT/hp31C83SBx/8BabMvQ+UTqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IB2yyuHQ9+MN80Aaj+98+qDfDIePa1BOrr9c8fefULApMAsGByqGSM49AgEFAARH
# MEUCIGytaGpn9cns9mX+d+bDcuaTxgqzP7tUGC7xdvKgYie9AiEA9tBI5bXyZHfA
# ny55zU3uoI2YzZlH71zSnQH90YKvWvE=
# SIG # End signature block
