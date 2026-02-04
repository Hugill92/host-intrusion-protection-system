# ==========================================
# FIREWALL MONITOR - INBOUND + OUTBOUND
# Event ID 5157 (Blocked Connections)
# ==========================================

$LogName = "Security"
$EventID = 5157
$Since   = (Get-Date).AddMinutes(-30)

$Events = Get-WinEvent -FilterHashtable @{
    LogName   = $LogName
    Id        = $EventID
    StartTime = $Since
} -ErrorAction SilentlyContinue

if (-not $Events) {
    Write-Host "[OK] No blocked inbound or outbound connections in the last 30 minutes."
    return
}

foreach ($Event in $Events) {
    $Xml = [xml]$Event.ToXml()

    $Direction = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "Direction" }).'#text'

    $Application = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "Application" }).'#text'

    $DestIP = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "DestAddress" }).'#text'

    $DestPort = ($Xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "DestPort" }).'#text'

    Write-Host "=============================="
    Write-Host "BLOCKED CONNECTION DETECTED"
    Write-Host "Direction   : $Direction"
    Write-Host "Application : $Application"
    Write-Host "Destination : ${DestIP}:${DestPort}"
    Write-Host "Time        : $($Event.TimeCreated)"
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBb8O+Vi2OBQMMk
# kGbLAcqUUcFa9b1jeBhRqllh4bipPKCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ILGjrYm9fDIG+SHcBbY2p57y7pUZQvYA6GFw/+EA7oYEMAsGByqGSM49AgEFAARI
# MEYCIQCx+Td1eADlNqryMgOw+TEmB1SA58sD5GBL4EabrglMogIhAMcUCAy8jNOW
# xLIsA694No/d4+qlvCOrccOOaCjgfSYy
# SIG # End signature block
