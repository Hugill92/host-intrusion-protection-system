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
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAVKL1+05AG0stj
# KbJJngRmnjWnzIgCbV4PcJi9eC2nSaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IIxM55cbIU+hE7PY5Ie/x0159/+nNPO3CFseshRemVbCMAsGByqGSM49AgEFAARH
# MEUCIQDcnowGmtzYaFwTRjJ5HvepZilUYxevzQgugA8Q176nUgIgKWZHBoD/rhRG
# elVwCXTvXJoCzFQPjWhYghiQzfl56iE=
# SIG # End signature block
