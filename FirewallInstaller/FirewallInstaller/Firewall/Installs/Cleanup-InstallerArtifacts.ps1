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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDhbxYyxcvIYMHH
# xOCajjX4sVWQkcEfsGgBKlrAlxoMH6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IAeDqCU4BYoAOvz8vodKj8sOa+PfrleOeXih9ELtNZtgMAsGByqGSM49AgEFAARH
# MEUCIEcQYcOAyf0S+ncUUWjj9HeLSa11eDK/GCJzSPyKY0B/AiEA+XJXVC3Q3F4M
# PVkWpRyzK2SoFb3QU+1ha/r6c1csb+c=
# SIG # End signature block
