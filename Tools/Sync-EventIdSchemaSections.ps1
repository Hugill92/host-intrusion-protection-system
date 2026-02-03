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
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU4O1Y3u7b2DhKt0S53G1Iz6PO
# PN2gggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUQ7Q2xT5zdufWXVXQI1yzsJpYtOswCwYH
# KoZIzj0CAQUABEcwRQIgVmVayneelqPmhQFVrRtqxzmnfIsL0r0fnSDmCsoIkX8C
# IQD4wMb0NasycVEBSeXWt+/CtXLEL/8kYkAQBpk5Vesaeg==
# SIG # End signature block
