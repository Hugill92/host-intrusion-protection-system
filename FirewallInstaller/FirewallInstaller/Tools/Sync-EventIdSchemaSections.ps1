[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$docPath = Join-Path $RepoRoot "Docs\EVENT_ID_SCHEMA.md"
if (!(Test-Path -LiteralPath $docPath)) {
  throw "Missing $docPath. Run Tools\New-NotifierTestDocs.ps1 first."
}

$beginBands = "<!-- BEGIN: EventIdBands -->"
$endBands   = "<!-- END: EventIdBands -->"
$beginActor = "<!-- BEGIN: ActorAttribution -->"
$endActor   = "<!-- END: ActorAttribution -->"

$bandsBlock = @(
  $beginBands
  "| Band | Range | Severity / Meaning | Notes |"
  "|---:|---:|---|---|"
  "| 3000 | 3000–3999 | **Info** | Informational / baseline / allowed outcomes |"
  "| 4000 | 4000–4999 | **Warning** | Suspicious / needs review / policy drift |"
  "| 8000 | 8000–8999 | **Test / Pentest / Diagnostics** | Synthetic events used by test harness |"
  "| 9000 | 9000–9999 | **Critical** | Confirmed bad / requires manual review |"
  $endBands
) -join "`r`n"

$actorBlock = @(
  $beginActor
  "Recommended fields when emitting notifier payloads and/or audit logs:"
  ""
  "- **Actor.User**: Username / SID context when relevant"
  "- **Actor.ProcessName**: Image name (e.g. `powershell.exe`)"
  "- **Actor.ProcessPath**: Full path when available"
  "- **Actor.ProcessId**: PID when known"
  "- **Actor.ParentProcessName** / **Actor.ParentProcessId**: Parent context (if known)"
  "- **Actor.ServiceName**: If action occurred under a service"
  "- **Actor.Hostname**: Machine name"
  "- **Actor.Source**: Component emitting the event (e.g. `FirewallCore.Notifiers`, `FirewallCore.Pentest`)"
  ""
  "Rules:"
  "- Prefer stable **Source** and **ProcessPath** over fragile strings."
  "- If data is unknown, omit the field (don’t guess)."
  $endActor
) -join "`r`n"

function Upsert-Section {
  param([string]$Content,[string]$Begin,[string]$End,[string]$NewBlock,[switch]$Force)
  $b = [regex]::Escape($Begin)
  $e = [regex]::Escape($End)
  $pattern = "(?s)$b.*?$e"

  if ($Content -match $pattern) {
    return [regex]::Replace($Content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $NewBlock }, 1)
  }

  if (-not $Force) {
    throw "Missing required markers ($Begin / $End). Re-run with -Force to append them."
  }

  return ($Content.TrimEnd() + "`r`n`r`n" + $NewBlock + "`r`n")
}

$raw = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8

$updated = Upsert-Section -Content $raw -Begin $beginBands -End $endBands -NewBlock $bandsBlock -Force:$Force
$updated = Upsert-Section -Content $updated -Begin $beginActor -End $endActor -NewBlock $actorBlock -Force:$Force

$bak = "$docPath.bak_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item -LiteralPath $docPath -Destination $bak -Force

Set-Content -LiteralPath $docPath -Value $updated -Encoding UTF8
Write-Host "UPDATED: $docPath" -ForegroundColor Green
Write-Host "Backup : $bak" -ForegroundColor DarkGray

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC9/bm2HB8zsDic
# C89lxAlhfXyFsE4/WxEceRqq0MEvYqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IAIJQc1z6lgSVmZ7b7Mb29gF6G3MvLwdSBIzYEB4fQoxMAsGByqGSM49AgEFAARI
# MEYCIQC468VnypNIbEDJXNH3IhpUP+jY+zPU+6oQbrXXEvsbgAIhAJSkfB5gT1/i
# kIwgPTCdl7+qEP6GgDAc3aeEI9gbIy6n
# SIG # End signature block
