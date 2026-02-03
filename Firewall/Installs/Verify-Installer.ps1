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
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUg2DPshcR+SNejkYGzeYHlUZY
# 1TGgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBJDCCASACAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUcCI3jx9TvKZ7+AIPy/F8rEK6kXQwCwYH
# KoZIzj0CAQUABEgwRgIhAK79t4ZSzIsMBo3u6RyDg5fwHrTi4kK5IteGlLURLmXj
# AiEAiGpF6gir+mM3SW6t1EEidPh5xMf7iVkttupuF1rY8hA=
# SIG # End signature block
