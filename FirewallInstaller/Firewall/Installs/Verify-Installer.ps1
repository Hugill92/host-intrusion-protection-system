# Verify-Installer.ps1
# Verifies installer-side modules and logic only

# ================== DEV / INSTALLER MODE ==================
# NEVER remove this section
# Controls whether script operates on LIVE system or INSTALLER sandbox

param(
    [switch]$DevMode
)

if ($DevMode) {
    $Root        = "C:\FirewallInstaller\Firewall"
    $ModulesDir  = "$Root\Modules"
    $StateDir    = "$Root\State"
    $Snapshots   = "$Root\Snapshots"
    $DiffDir     = "$Root\Diff"
    $LogsDir     = "$Root\Logs"
    $IsLive      = $false
} else {
    $Root        = "C:\Firewall"
    $ModulesDir  = "$Root\Modules"
    $StateDir    = "$Root\State"
    $Snapshots   = "$Root\Snapshots"
    $DiffDir     = "$Root\Diff"
    $LogsDir     = "$Root\Logs"
    $IsLive      = $true
}

# Safety guard
if ($IsLive -and -not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Live mode requires elevation"
}
# ==========================================================


Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstallerRoot = "C:\FirewallInstaller\Firewall"

Write-Output "=== VERIFY INSTALLER ==="

# Import modules from installer only
Import-Module "$InstallerRoot\Modules\FirewallSnapshot.psm1" -Force
Import-Module "$InstallerRoot\Modules\Diff-FirewallSnapshots.psm1" -Force
. "$InstallerRoot\Modules\Firewall-EventLog.ps1"

Write-Output "[VERIFY] Modules imported successfully"

# Snapshot test (installer context)
$snapshot = Get-FirewallSnapshot -Fast -SnapshotDir "$InstallerRoot\Snapshots"

if (-not $snapshot.Path) {
    throw "Snapshot failed"
}

Write-Output "[VERIFY] Snapshot OK"
Write-Output "  Path : $($snapshot.Path)"
Write-Output "  Hash : $($snapshot.Hash)"
Write-Output "  Rules: $($snapshot.RuleCount)"

# Diff test
$diff = Compare-FirewallSnapshots `
    -SnapshotDir "$InstallerRoot\Snapshots" `
    -DiffDir "$InstallerRoot\Diff"

if ($diff) {
    Write-Output "[VERIFY] Diff OK"
    Write-Output "  Added   : $($diff.AddedCount)"
    Write-Output "  Removed : $($diff.RemovedCount)"
    Write-Output "  Modified: $($diff.ModifiedCount)"
} else {
    Write-Output "[VERIFY] Diff skipped (not enough snapshots)"
}

# Event emission test (noisy but safe)
Write-FirewallEvent `
    -EventId 4099 `
    -Type Information `
    -Message "Installer verification test event"

Write-Output "=== VERIFY COMPLETE ==="

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB8FaAMf3uuG6pL
# kZMaZ7X5XwJXaxGgqvBZE6RWa+gPLaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IB6ScITkDjz8sPfrlB85GtY4GJnw7d7mgp8voBfEy39kMAsGByqGSM49AgEFAARH
# MEUCIBKfuaOdmFgp1PkyIwcRb/xa4eBdrMRgk5WKQcrTZRG/AiEAsiISqa2ciNdO
# Uotj7kvQfHZSD7XK6ARQUGyTZkES3F4=
# SIG # End signature block
