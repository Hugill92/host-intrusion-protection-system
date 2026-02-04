# Test-SelfHeal-Event.ps1
# Triggers firewall drift and verifies restore event (3001)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq 'True' } |
    Select-Object -First 1

if (-not $rule) {
    Write-Host "[FAIL] No enabled firewall rules found."
    exit 1
}

Write-Host "[TEST] Disabling firewall rule:"
Write-Host "       Name: $($rule.Name)"
Write-Host "       Direction: $($rule.Direction)"

Disable-NetFirewallRule -Name $rule.Name

Write-Host "[OK] Rule disabled."
Write-Host "[WAIT] Waiting for self-heal (6 minutes)..."
Write-Host "       Expect exactly ONE Event ID 3001."

Start-Sleep -Seconds 360

$event = Get-WinEvent -LogName Firewall |
    Where-Object {
        $_.Id -eq 3001 -and
        $_.Message -like "*$($rule.Name)*"
    } |
    Select-Object -First 1

if ($event) {
    Write-Host "[PASS] Restore event detected:"
    $event | Format-List TimeCreated, Id, Message
}
else {
    Write-Host "[FAIL] No restore event found for rule $($rule.Name)."
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDEdE7lXX5zR4rP
# gvSULqH2RBgb2s56LtlYctHtH3LjwqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IIHuVi7hIzePbyZsBSTieNX+I1gndfZUeGGmFIRg6vcfMAsGByqGSM49AgEFAARI
# MEYCIQCAP5mhd/rSM9zwOmvIkDrSZQGpax3LswE7ns0utUDkZQIhAKqW3BAVHLAM
# R5aSHYKsJEe/8+jYbW4pouw66AHWzvf5
# SIG # End signature block
