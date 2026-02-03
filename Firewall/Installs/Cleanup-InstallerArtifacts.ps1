<#
Cleanup-InstallerArtifacts.ps1

Purpose:
- One-click cleanup of installer artifacts
- Auto-elevates if not running as Administrator
- SAFE: operates ONLY inside installer tree
- Prepares project for signing + GitHub release
- Reusable core for future uninstaller
#>

# ================= AUTO-ELEVATION =================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}
# ==================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------- CONFIG ----------------
$InstallerRoot = "C:\FirewallInstaller\Firewall"

$ArtifactDirs = @(
    "Snapshots",
    "Diff",
    "Logs",
    "Tools\Snapshots",
    "Tools\Diffs"
)

$StateDir = Join-Path $InstallerRoot "State"

# Explicit state files to delete
$StateFiles = @(
    "snapshot.history.json",
    "snapshot.last.hash",
    "firewall.rules.hash",
    "baseline.hash",
    "baseline.meta.json",
    "baseline.integrity.json",
    "event_rate.json",
    "alert.state.json",
    "maintenance.token",
    "admin-override.token",
    "wfp.strikes.json",
    "wfp.strikes.log",
    "wfp.strikes.state",
    "install.debug.log",
    "install.trace.log",
    "install-error.log"
)

# Files that must NEVER be removed
$ProtectedStateFiles = @(
    "baseline.json",
    "allowlist.json",
    "forwarding.json"
)
# ----------------------------------------

function Clear-DirectoryContents {
    param([string]$Path)

    if (Test-Path $Path) {
        Get-ChildItem $Path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Write-Host ""
Write-Host "============================================="
Write-Host " Firewall Installer Cleanup (ADMIN)"
Write-Host "============================================="
Write-Host " Target: $InstallerRoot"
Write-Host ""

if (-not (Test-Path $InstallerRoot)) {
    Write-Error "Installer root not found: $InstallerRoot"
    exit 1
}

# ---------------- CLEAN ARTIFACT DIRECTORIES ----------------
foreach ($dir in $ArtifactDirs) {
    $full = Join-Path $InstallerRoot $dir
    Write-Host "[CLEAN] $dir"
    Clear-DirectoryContents -Path $full
}

# ---------------- CLEAN STATE FILES ----------------
if (Test-Path $StateDir) {

    foreach ($file in $StateFiles) {
        $path = Join-Path $StateDir $file
        if (Test-Path $path) {
            Write-Host "[REMOVE] State\$file"
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }

    # Pattern-based cleanup (safe, excludes protected)
    $patterns = @("*.jsonl","*.log","*.tmp","*.bak","*.old","*.hash","*.token")

    foreach ($pattern in $patterns) {
        Get-ChildItem $StateDir -Filter $pattern -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $ProtectedStateFiles } |
            ForEach-Object {
                Write-Host "[REMOVE] State\$($_.Name)"
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
    }
}

# ---------------- FINAL PII SAFETY SWEEP ----------------
Write-Host "[VERIFY] PII sweep (best-effort)"

Get-ChildItem $InstallerRoot -Recurse -Include *.log,*.txt,*.json -ErrorAction SilentlyContinue |
    ForEach-Object {
        try {
            $content = Get-Content $_.FullName -Raw -ErrorAction Stop
            if ($content -match $env:USERNAME -or
                $content -match $env:COMPUTERNAME -or
                $content -match "S-1-5-21-") {

                Write-Host "[WARN] Potential PII found in $($_.FullName)"
            }
        } catch {}
    }

Write-Host ""
Write-Host "[OK] Installer cleanup complete."
Write-Host ""
Write-Host "You may now:"
Write-Host " - Sign scripts"
Write-Host " - Upload to GitHub"
Write-Host " - Run installer cleanly"
Write-Host ""
Pause

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGMfR1B36QsQ0VWpjwOiaS7mP
# 2bqgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUakYdCS64i3zQlnH2EGY7upCVYEQwCwYH
# KoZIzj0CAQUABEcwRQIgJMsuqMXUNfSP19WGpzcK6mEUX6KMatpymUN350iSLEoC
# IQCuxgHx7TXdKqnpO4GoY+9uDQxZFjT6TGQxv/7IHqRtrw==
# SIG # End signature block
