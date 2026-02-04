# Test-Firewall-User-Audit.ps1
# Purpose: Normal USER firewall change -> self-heal -> audit attribution test
# Run as NON-ADMIN

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Pick a random enabled firewall rule
$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq "True" } |
    Get-Random

if (-not $rule) {
    Write-Host "[FAIL] No enabled firewall rules found."
    exit 1
}

$ruleName = $rule.Name

Write-Host "Disabling firewall rule as USER:"
Write-Host "  Name: $ruleName"
Write-Host ""

# Disable rule
Disable-NetFirewallRule -Name $ruleName

Write-Host "Rule disabled."
Write-Host "Waiting for self-heal and audit attribution (about 2-3 minutes)..."
Write-Host ""

# Wait longer than audit interval
Start-Sleep -Seconds 160

# Verify rule restored
$restored = (Get-NetFirewallRule -Name $ruleName).Enabled

# Check Firewall log for audit event
$auditEvent = Get-WinEvent -LogName Firewall -MaxEvents 50 |
    Where-Object {
        $_.Id -eq 9300 -and $_.Message -match [regex]::Escape($ruleName)
    } |
    Select-Object -First 1

Write-Host "RESULTS:"
Write-Host "--------"

if ($restored -eq "True") {
    Write-Host "[OK] Rule was self-healed"
} else {
    Write-Host "[FAIL] Rule was NOT restored"
}

if ($auditEvent) {
    Write-Host "[OK] Audit event detected:"
    Write-Host "     $($auditEvent.Message)"
} else {
    Write-Host "[FAIL] No audit attribution event (9300) found"
}

exit 0

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCrD4FMzLMJxl7W
# 0Y7AmsKsIUD1eW5l69BS9+koM9K8baCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggEzMIIBLwIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IP201C7be43T2Mvk436Sb5KR6y1BLQOQyG+FRnBYn6KDMAsGByqGSM49AgEFAARG
# MEQCIF3u2NglBcXAxjYeXTBU8MlVPXQwgZ+06iZU3Wx4iS9JAiBhLRQgd0MvT46H
# phKReHoK0ucsm3Q8iEsQebRXJ6duZg==
# SIG # End signature block
