<#
.SYNOPSIS
  Ensures a PREINSTALL firewall baseline exists (or is created).

.DESCRIPTION
  Creates (or verifies) a baseline bundle under:
    <ProgramDataRoot>\Baselines\PREINSTALL_YYYYMMDD_HHMMSS\

  Required artifacts:
    - Firewall-Policy.wfw
    - Firewall-Policy.json
    - Firewall-Policy.thc (stub until generator exists)
    - FirewallBaseline.manifest.sha256.json

  Uses Tools/Modules/FirewallBaseline.psm1 for:
    - Fingerprint
    - Manifest generation
    - Manifest verification
#>

[CmdletBinding()]
param(
  [string]$ProgramDataRoot = "C:\ProgramData\FirewallCore",
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$PSNativeCommandUseErrorActionPreference = $true

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$baselineModule = Join-Path $repoRoot "Tools\\Modules\\FirewallBaseline.psm1"
Import-Module $baselineModule -Force

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  throw "Ensure-PreInstallBaseline must be run elevated (Administrator)."
}

$baselineRoot = Join-Path $ProgramDataRoot "Baselines"
New-Item -ItemType Directory -Path $baselineRoot -Force | Out-Null

$requiredFiles = @(
  "Firewall-Policy.wfw",
  "Firewall-Policy.json",
  "Firewall-Policy.thc",
  "FirewallBaseline.manifest.sha256.json"
)

function Test-RequiredBaselineFiles {
  param([Parameter(Mandatory)][string]$Dir)

  foreach ($name in $requiredFiles) {
    $p = Join-Path $Dir $name
    if (-not (Test-Path -LiteralPath $p)) {
      throw ("Required baseline file missing: {0}" -f $p)
    }

    if ($name -like "*.wfw" -or $name -like "*.json" -or $name -like "*.thc") {
      $len = (Get-Item -LiteralPath $p).Length
      if ($len -le 0) {
        throw ("Required baseline file is empty: {0}" -f $p)
      }
    }
  }
}

function Get-LatestExistingPreinstallBaseline {
  $dirs = Get-ChildItem -LiteralPath $baselineRoot -Directory -Filter "PREINSTALL_*" -ErrorAction SilentlyContinue
  if (-not $dirs) { return $null }
  return ($dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
}

$existing = Get-LatestExistingPreinstallBaseline
if ($existing -and -not $Force) {
  Test-RequiredBaselineFiles -Dir $existing.FullName
  $verify = Test-FirewallBaselineManifest -BaselineDir $existing.FullName -InventoryJsonName "Firewall-Policy.json"
  if (-not $verify.Ok) {
    throw ("Existing PREINSTALL baseline failed verification: {0}" -f (($verify.Failures -join "; ")))
  }

  return [pscustomobject]@{
    Created       = $false
    BaselinePath  = $existing.FullName
    Reason        = "baseline-exists"
    Verification  = $verify
  }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$bundleDir = Join-Path $baselineRoot ("PREINSTALL_{0}" -f $stamp)
New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null

$wfwPath  = Join-Path $bundleDir "Firewall-Policy.wfw"
$jsonPath = Join-Path $bundleDir "Firewall-Policy.json"
$thcPath  = Join-Path $bundleDir "Firewall-Policy.thc"

# 1) Export authoritative firewall policy (WFAS)
& netsh advfirewall export $wfwPath | Out-Null
if (-not (Test-Path -LiteralPath $wfwPath)) { throw "Firewall export did not produce output: $wfwPath" }
if ((Get-Item -LiteralPath $wfwPath).Length -le 0) { throw "Firewall export produced empty file: $wfwPath" }

# 2) Inventory JSON (includes Rules[] for deterministic fingerprinting)
$rules = Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction Stop
$ruleRecords = foreach ($r in $rules) {
  [pscustomobject]@{
    DisplayName = [string]$r.DisplayName
    Direction   = [string]$r.Direction
    Action      = [string]$r.Action
    Enabled     = [string]$r.Enabled
    Profile     = [string]$r.Profile
    Group       = if ($null -eq $r.Group) { "" } else { [string]$r.Group }
  }
}

$warnings = New-Object System.Collections.Generic.List[string]
$warnings.Add("THC artifact is currently a stub (generator not wired).")

$inventory = [ordered]@{
  Type      = "PREINSTALL"
  CreatedAt = (Get-Date).ToString("o")
  Computer  = $env:COMPUTERNAME
  User      = $env:USERNAME
  Export    = [ordered]@{
    Method = "netsh advfirewall export"
    File   = "Firewall-Policy.wfw"
  }
  RuleCount = $ruleRecords.Count
  Rules     = $ruleRecords
  Warnings  = @($warnings)
}

($inventory | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

# 3) THC artifact (stub for now)
"THC artifact stub (generator not wired yet)." | Set-Content -LiteralPath $thcPath -Encoding UTF8

# 4) Manifest + verification
$filesForManifest = @("Firewall-Policy.wfw","Firewall-Policy.json","Firewall-Policy.thc")
$manifestPath = New-FirewallBaselineManifest -BaselineDir $bundleDir -Files $filesForManifest -Type "PREINSTALL" -PolicyStore "ActiveStore" -Warnings @($warnings) -InventoryJsonName "Firewall-Policy.json"

Test-RequiredBaselineFiles -Dir $bundleDir
$verifyNew = Test-FirewallBaselineManifest -BaselineDir $bundleDir -InventoryJsonName "Firewall-Policy.json"
if (-not $verifyNew.Ok) {
  throw ("New PREINSTALL baseline failed verification: {0}" -f (($verifyNew.Failures -join "; ")))
}

return [pscustomobject]@{
  Created       = $true
  BaselinePath  = $bundleDir
  Reason        = "created"
  ManifestPath  = $manifestPath
  Verification  = $verifyNew
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKgoaPPp/EuN51
# vr+xdg+CCMYRbpDelVaV/2U223lZ2qCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IO+oEB+0FgQAMAY8u4XQBLH+rIX9jvUY8DuotA7lbD1oMAsGByqGSM49AgEFAARI
# MEYCIQCAlpUVRzShR9fhscAlqVKUbD4POrvwDo4hPc153mCdAAIhANmRheOncGsd
# 5RlkInBclY6ocoa2ouXQpKa0VFJ6WNhS
# SIG # End signature block
