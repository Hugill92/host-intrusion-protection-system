# ==========================================
# FIREWALL BOOTSTRAP (SELF-HEAL)
# ==========================================

$TaskName   = "Firewall Core Monitor"
$ScriptPath = "C:\Firewall\Monitor\Firewall-Core.ps1"

$Exists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

# --- FIX WMI FIREWALL PERMISSIONS ---
$ns = "root\standardcimv2"
$sd = Get-CimInstance -Namespace root\cimv2 -ClassName __SystemSecurity

$admins = "BUILTIN\Administrators"
$users  = "BUILTIN\Users"

# Reset to safe baseline
Invoke-CimMethod -InputObject $sd -MethodName SetSecurityDescriptor `
    -Arguments @{ Descriptor = (Get-CimInstance -Namespace root\cimv2 -ClassName Win32_SecurityDescriptor) }

# Admins = Full
$null = cmd /c "wmic /namespace:\\root\standardcimv2 path __systemsecurity call SetSecurityDescriptor `"D:(A;;CCDCLCSWRPWPRCWD;;;BA)(A;;CCLCSWLO;;;BU)`""


if (-not $Exists) {

    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$ScriptPath`""

    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    $Trigger.RepetitionInterval = (New-TimeSpan -Minutes 5)
    $Trigger.RepetitionDuration = (New-TimeSpan -Days 1)

    $Principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    $Settings = New-ScheduledTaskSettingsSet `
        -Hidden `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Force
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDtuH3wQZ52X9Q4
# zSYkhmbSPwXpWeS3IlgGCitqY1GAT6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IBqy119E+CUEXZ9JSy+ax2HoEYei3f8R0GEpb6Lf1XGJMAsGByqGSM49AgEFAARI
# MEYCIQCXNtKEtr3FfqrXVtl32dYqFKVHoyjhlcjhFsC+mqrJ6wIhAJB44w1r8w26
# c04Ekex6E7f+Oooffps4UYtPiHr0aCyw
# SIG # End signature block
