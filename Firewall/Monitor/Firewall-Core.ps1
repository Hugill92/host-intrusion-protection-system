# ============================================================
# Firewall-Core.ps1
# SYSTEM firewall monitor + self-heal coordinator
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -------------------- EXECUTION POLICY SELF-BYPASS --------------------
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Error "Constrained language mode detected. Exiting."
    exit 1
}

if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit $LASTEXITCODE
}
# ---------------------------------------------------------------------

# -------------------- PATH RESOLUTION (DEV / LIVE SAFE) ----------------
if ($env:FIREWALL_DEV_MODE -eq "1") {
    # Installer tree (DEV)
    $RootDir     = "C:\FirewallInstaller\Firewall"
} else {
    # Live system
    $RootDir     = "C:\Firewall"
}

$ModulesDir  = Join-Path $RootDir "Modules"
$StateDir    = Join-Path $RootDir "State"
$LogDir      = Join-Path $RootDir "Logs"
$SnapshotDir = Join-Path $RootDir "Snapshots"
$DiffDir     = Join-Path $RootDir "Diff"

foreach ($d in @($StateDir,$LogDir,$SnapshotDir,$DiffDir)) {
    if (!(Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}
# ---------------------------------------------------------------------

# -------------------- IMPORT HELPERS --------------------
. "$ModulesDir\Firewall-EventLog.ps1"

Import-Module "$ModulesDir\FirewallSnapshot.psm1"        -Force
Import-Module "$ModulesDir\Diff-FirewallSnapshots.psm1"  -Force
Import-Module "$ModulesDir\Firewall-SnapshotEvents.psm1" -Force
# -------------------------------------------------------

# ================= SNAPSHOT AUDIT =================
try {
    $snap = Get-FirewallSnapshot `
        -Fast `
        -SnapshotDir $SnapshotDir `
        -StateDir $StateDir

    $diff = Compare-FirewallSnapshots

    if ($diff) {
        Emit-FirewallSnapshotEvent `
            -Snapshot $snap `
            -Diff $diff `
            -Mode ($env:FIREWALL_DEV_MODE ? "DEV" : "LIVE")
    }
}
catch {
    Write-FirewallEvent `
        -EventId 4999 `
        -Type Error `
        -Message "Snapshot pipeline failure: $($_.Exception.Message)"
}
# ==================================================


# ==========================================
# SNAPSHOT → DIFF → EVENT PIPELINE
# ==========================================

try {
    if ($env:FIREWALL_DEV_MODE -eq "1") {
        Write-Host "[DEV] Running snapshot pipeline from installer tree"
    }

    $snapshot = Get-FirewallSnapshot `
        -Fast `
        -SnapshotDir $SnapshotDir `
        -StateDir    $StateDir

    $diff = Compare-FirewallSnapshots

    Emit-FirewallSnapshotEvent `
        -Snapshot $snapshot `
        -Diff     $diff `
        -Mode     ($(if ($env:FIREWALL_DEV_MODE -eq "1") { "DEV" } else { "LIVE" })) `
        -RunId    "CORE"

}
catch {
    Write-FirewallEvent `
        -EventId 4999 `
        -Type Error `
        -Message "Firewall Core snapshot pipeline failed: $($_.Exception.Message)"
}


$RunId = [guid]::NewGuid().ToString()

# -------------------- HEARTBEAT -------------------------
Write-FirewallEvent `
    -EventId 1000 `
    -Type Information `
    -Message "Firewall Core heartbeat. RunId=$RunId"
# -------------------------------------------------------

# -------------------- BASELINE PRESENCE -----------------
$BaselinePath = Join-Path $StateDir "baseline.json"

if (!(Test-Path $BaselinePath)) {
    Write-FirewallEvent `
        -EventId 3100 `
        -Type Error `
        -Message "Firewall baseline missing. Enforcement skipped. RunId=$RunId"
    exit 0
}

Write-FirewallEvent `
    -EventId 1100 `
    -Type Information `
    -Message "Firewall baseline present. RunId=$RunId"
# -------------------------------------------------------

# -------------------- SNAPSHOT + DIFF -------------------
$snapshot = Get-FirewallSnapshot `
    -Fast `
    -SnapshotDir $SnapshotDir `
    -StateDir    $StateDir
    
# ================= SNAPSHOT HASH SHORT-CIRCUIT =================

$lastHashPath = Join-Path $StateDir "snapshot.last.hash"

if (Test-Path $lastHashPath) {
    $lastHash = (Get-Content $lastHashPath -Raw -ErrorAction SilentlyContinue).Trim()

    if ($lastHash -and $lastHash -eq $Snapshot.Hash) {
        if ($env:FIREWALL_DEV_MODE -eq "1") {
            Write-Host "[DEV] Snapshot hash unchanged — skipping diff/enforcement"
        }
        return
    }
}

# Persist new hash
$Snapshot.Hash | Set-Content -Path $lastHashPath -Encoding ascii

# ================= Cmopare Snapshots =================

$diff = Compare-FirewallSnapshots `
    -SnapshotDir $SnapshotDir `
    -DiffDir     $DiffDir

Emit-FirewallSnapshotEvent `
    -Snapshot $snapshot `
    -Diff     $diff `
    -Mode     "CORE" `
    -RunId    $RunId
# -------------------------------------------------------

# -------------------- DEFAULT PROFILE TAMPER CHECK ------
$profiles = Get-NetFirewallProfile -Profile Domain,Private,Public |
            Where-Object { $_.DefaultInboundAction -ne "Block" }

if ($profiles) {
    Write-FirewallEvent `
        -EventId 3002 `
        -Type Warning `
        -Message "Firewall inbound default drift detected. Restoring to Block. RunId=$RunId"

    Get-NetFirewallProfile | Set-NetFirewallProfile -DefaultInboundAction Block

    Write-FirewallEvent `
        -EventId 3001 `
        -Type Information `
        -Message "Firewall inbound default restored to Block. RunId=$RunId"
}
# -------------------------------------------------------

# -------------------- API HEALTH CHECK ------------------
try {
    Get-NetFirewallRule -ErrorAction Stop | Out-Null
} catch {
    Write-FirewallEvent `
        -EventId 4001 `
        -Type Error `
        -Message "Firewall API access failed (Get-NetFirewallRule). RunId=$RunId"
}
# -------------------------------------------------------

exit 0

# SIG # Begin signature block
# MIIEbwYJKoZIhvcNAQcCoIIEYDCCBFwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqmoV5GvMz37d6XnMfU2V7v1c
# KGCgggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8Vwx4/Txbw+q56YitPRZTY1s+w4wCwYH
# KoZIzj0CAQUABEgwRgIhAMRR7UFecXrLDU3Y8Nxth0H1YRwTYPyLcphEQ1sZwm5P
# AiEA5l0KYsmrUTje8zzcx3dsO1HnGJvelWzp5nFqc4iB77Q=
# SIG # End signature block
