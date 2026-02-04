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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDwwIffsh04GZ6M
# 8CUZaFV9Tw+vMgD7DpqlwpQJghhuCaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ICCGl+fWLsK4CQt8Aqma9ext1FHS02T3Sz7W1tYE79FUMAsGByqGSM49AgEFAARH
# MEUCIE5gAQl1QJMdd4XYnPpK54zQn0y3X1TYX+dWmRWsMtXSAiEAkLNn3Y90LImn
# edcto0pHHLsNI8adw4jtiKfwd7jcH9c=
# SIG # End signature block
