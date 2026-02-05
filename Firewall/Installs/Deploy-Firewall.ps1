# Deploy-Firewall.ps1
# Atomic redeploy of Firewall system from installer → live

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
$LiveRoot      = "C:\Firewall"

$TaskNames = @(
    "Firewall Core Monitor",
    "Firewall WFP Monitor"
)

Write-Output "[DEPLOY] Starting firewall redeploy..."

# Stop scheduled tasks if present
foreach ($t in $TaskNames) {
    try {
        if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
            Write-Output "[DEPLOY] Stopping task: $t"
            Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
        }
    } catch {}
}

# Ensure live root exists
if (!(Test-Path $LiveRoot)) {
    New-Item -ItemType Directory -Path $LiveRoot -Force | Out-Null
}

# Copy installer payload → live
Write-Output "[DEPLOY] Copying files to live directory..."
Copy-Item `
    -Path "$InstallerRoot\*" `
    -Destination $LiveRoot `
    -Recurse -Force

# Restart scheduled tasks
foreach ($t in $TaskNames) {
    try {
        if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
            Write-Output "[DEPLOY] Starting task: $t"
            Start-ScheduledTask -TaskName $t
        }
    } catch {}
}

Write-Output "[DEPLOY] Redeploy complete."

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD1iyNCnGfGsdIm
# FXnOiS0hJnQqECrKO7IIfXt3Sq+iaqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IKLE2jL/ZOZlku3riX1XwE8rHBXGWEyTGXlmycez+3qYMAsGByqGSM49AgEFAARI
# MEYCIQDXaWnifgNH14hcv1oE3pwi+zJOrgc1QbevDTRkgCN4rwIhAMx21rut/rL4
# v+lYrytrDW2P5YqgtDYBE8YrPpx+APGE
# SIG # End signature block
