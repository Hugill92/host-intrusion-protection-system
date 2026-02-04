# ==========================================
# FIREWALL BLOCK NOTIFIER (USER CONTEXT)
# ==========================================

$LogFile   = "C:\Firewall\Logs\Firewall-Blocked.log"
$StateFile = "$env:LOCALAPPDATA\FirewallNotify.last"

if (-not (Test-Path $LogFile)) {
    return
}

$LastRead = if (Test-Path $StateFile) {
    Get-Content $StateFile | Get-Date
} else {
    Get-Date "2000-01-01"
}

$NewEvents = Get-Content $LogFile |
    Where-Object {
        ($_ -match '^\d{4}-\d{2}-\d{2}') -and
        ((Get-Date ($_ -split '\|')[0]) -gt $LastRead)
    }

if (-not $NewEvents) {
    return
}

# Update state
(Get-Date).ToString("o") | Set-Content $StateFile

# Load toast support
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null

$Template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>Firewall Blocked Connection</text>
      <text>$($NewEvents[-1])</text>
    </binding>
  </visual>
</toast>
"@

$Xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$Xml.LoadXml($Template)

$Toast = [Windows.UI.Notifications.ToastNotification]::new($Xml)
$Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Firewall Monitor")
$Notifier.Show($Toast)

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCClR959TevvWhC1
# +j48X/LJbTjaFSL9kjlV2fi+HLhpWqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IKosPiTwpwMglff+S7NzogEPudmJDw6WqkqqOr0YgRRkMAsGByqGSM49AgEFAARH
# MEUCIQCS/Htpj3lkf970YZjM1RnnAHbSJrApMN1TCzes60kTxgIgSHFbcZZ6PXRD
# 3SQRmC5VNf3iq/i+qC/MHg1KeBkM6Ao=
# SIG # End signature block
