[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$Force
)

$docsDir = Join-Path $RepoRoot "Docs"
New-Item -ItemType Directory -Path $docsDir -Force | Out-Null

function Write-Doc {
  param([string]$Path,[string]$Content,[switch]$Force)
  if ((Test-Path -LiteralPath $Path) -and -not $Force) {
    Write-Host "SKIP (exists): $Path  (use -Force to overwrite)" -ForegroundColor Yellow
    return
  }
  Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
  Write-Host "WROTE: $Path" -ForegroundColor Green
}

$eventSchemaPath = Join-Path $docsDir "EVENT_ID_SCHEMA.md"
$viewsPath       = Join-Path $docsDir "VIEWS.md"

$eventSchema = @"
# FirewallCore Event ID Schema

This document defines the **EventId bands**, their meaning, and the **actor attribution** fields expected in notifier payloads / logs.

## EventId bands (canonical)

<!-- BEGIN: EventIdBands -->
| Band | Range | Severity / Meaning | Notes |
|---:|---:|---|---|
| 3000 | 3000–3999 | **Info** | Informational / baseline / allowed outcomes |
| 4000 | 4000–4999 | **Warning** | Suspicious / needs review / policy drift |
| 8000 | 8000–8999 | **Test / Pentest / Diagnostics** | Synthetic events used by test harness |
| 9000 | 9000–9999 | **Critical** | Confirmed bad / requires manual review |
<!-- END: EventIdBands -->

## Actor attribution (canonical)

<!-- BEGIN: ActorAttribution -->
Recommended fields when emitting notifier payloads and/or audit logs:

- **Actor.User**: Username / SID context when relevant
- **Actor.ProcessName**: Image name (e.g. `powershell.exe`)
- **Actor.ProcessPath**: Full path when available
- **Actor.ProcessId**: PID when known
- **Actor.ParentProcessName** / **Actor.ParentProcessId**: Parent context (if known)
- **Actor.ServiceName**: If action occurred under a service
- **Actor.Hostname**: Machine name
- **Actor.Source**: Component emitting the event (e.g. `FirewallCore.Notifiers`, `FirewallCore.Pentest`)

Rules:
- Prefer stable **Source** and **ProcessPath** over fragile strings.
- If data is unknown, omit the field (don’t lie / don’t guess).
<!-- END: ActorAttribution -->
"@

$viewsDoc = @"
# FirewallCore Event Viewer Views

## Canonical view files
These views are shipped/staged to allow deterministic “Review Log” drill-down by severity and/or bands.

### Single EventId views
- `FirewallCore-EventId-3001.xml`
- `FirewallCore-EventId-4001.xml`
- `FirewallCore-EventId-9001.xml`

### Range views
- `FirewallCore-Range-3000-3999.xml` (Info band)
- `FirewallCore-Range-4000-4999.xml` (Warning band)
- `FirewallCore-Range-8000-8999.xml` (Test/Pentest band)
- `FirewallCore-Range-9000-9999.xml` (Critical band)

## Install-time staging targets
- `%ProgramData%\Microsoft\Event Viewer\Views`
- `%ProgramData%\FirewallCore\User\Views`

## Permissions (important)
Standard users must be able to **read** the XML in ProgramData view folders.
Use `Tools\Ensure-EventViewerViewAcl.ps1` after staging/copy.
"@

Write-Doc -Path $eventSchemaPath -Content $eventSchema -Force:$Force
Write-Doc -Path $viewsPath       -Content $viewsDoc   -Force:$Force

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUg03f+S4NeSKODwWqnSzRUDR9
# kYegggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUer73IxA/AxvNfZNOawQkepRFpNIwCwYH
# KoZIzj0CAQUABEcwRQIgAwh8oA2exrYCu5oKGep3PLLDM0qkv5jBBQwJtAzyguUC
# IQD9SJJACB/3BVKpgiZkkBh2/fQKu7W9Crb6XIGPO02sYQ==
# SIG # End signature block
