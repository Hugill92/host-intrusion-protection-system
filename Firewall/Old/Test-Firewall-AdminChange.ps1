# Test-Firewall-AdminChange.ps1
# Purpose: Validate admin rule change + event logging
# Does NOT rely on self-heal

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- REQUIRE ADMIN ----
$principal = New-Object Security.Principal.WindowsPrincipal `
    ([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Error "This test must be run as Administrator."
    exit 1
}

# ---- LOAD EVENT LOG HELPER ----
. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# ---- PICK A STABLE RULE ----
$rule = Get-NetFirewallRule |
    Where-Object { $_.Enabled -eq "True" -and $_.Action -eq "Allow" } |
    Select-Object -First 1 Name, Direction

if (-not $rule) {
    Write-FirewallEvent `
        -EventId 9002 `
        -Type Error `
        -Message "No suitable firewall rule found for admin test."
    exit 1
}

$ruleName  = $rule.Name
$direction = $rule.Direction

# ---- TEST SEQUENCE ----
Write-FirewallEvent `
    -EventId 9200 `
    -Type Information `
    -Message "ADMIN TEST START: Disabling firewall rule '$ruleName'. Direction: $direction."

Disable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9201 `
    -Type Warning `
    -Message "ADMIN TEST ACTION: Firewall rule '$ruleName' disabled by Administrator."

Start-Sleep -Seconds 10

Enable-NetFirewallRule -Name $ruleName

Write-FirewallEvent `
    -EventId 9202 `
    -Type Information `
    -Message "ADMIN TEST COMPLETE: Firewall rule '$ruleName' re-enabled by Administrator."

exit 0

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDKIdEiJ/h5DjEg
# UDdPJPI1s54YrQnFtwnGCiv1Gl0e7qCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ILJZMD4N4cCO6AVxH1A+GhATubojhxAmlsCR+nZ2fg7DMAsGByqGSM49AgEFAARH
# MEUCIQD2oitQDQdxUMEFvpsBLqiIBS7asUBf7BgkFIcAbHN74AIgVCbXvEOhxUnS
# 29ZHNHSDJ1e+wp4G3DMYNkVGZwEBSkU=
# SIG # End signature block
