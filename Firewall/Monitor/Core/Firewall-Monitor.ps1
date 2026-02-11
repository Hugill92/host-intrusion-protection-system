. "C:\Firewall\Modules\Firewall-EventLog.ps1"


# ================= EXECUTION POLICY SELF-BYPASS =================
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Error "Constrained language mode detected. Exiting."
    exit 1
}

if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit $LASTEXITCODE
}
# =================================================================



# ==========================================
# FIREWALL MONITOR (INBOUND + OUTBOUND)
# Event ID 5157 - BLOCKED CONNECTIONS
# SYSTEM / SILENT / LOGGING ONLY
# ==========================================

$LogFile = "C:\Firewall\Logs\Firewall-Blocked.log"
$Since   = (Get-Date).AddMinutes(-5)

$Events = Get-WinEvent -FilterHashtable @{
    LogName   = "Security"
    Id        = 5157
    StartTime = $Since
} -ErrorAction SilentlyContinue

if (-not $Events) {
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

    $Line = "[{0}] {1} | {2} | {3}:{4}" -f `
        $Event.TimeCreated, $Direction, $Application, $DestIP, $DestPort

    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
}


Write-FirewallEvent `
    -Message "Firewall monitor heartbeat OK." `
    -EventId 1001 `
    -Type Information
	
	& "C:\Firewall\Monitor\Firewall-WFP-Analyze.ps1"

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCABnsleKpnQUVzy
# To9YipgipeMji1AnD1sodXpwhtMveqCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IBuTKz80EDD3qJqTsLMbe9qr8F5ifjT0D0526pDQeXjdMAsGByqGSM49AgEFAARG
# MEQCIBAO53BtAJ/aYmpVSJFWVSzzqe8yhnUX1PpxDtPHIxTHAiAL5X5DEnBMY1Fh
# SPlv2Jc6qdAj0AuxuOgx/X99qu2dRQ==
# SIG # End signature block
