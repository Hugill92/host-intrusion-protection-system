# Firewall-EventLog.ps1
# Helper module – defines Write-FirewallEvent ONLY
# NO side effects on import

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$Global:FirewallEventLogName = "Firewall"
$Global:FirewallEventSource  = "Firewall-Core"

function Write-FirewallEvent {
    param (
        [Parameter(Mandatory)]
        [int]$EventId,

        [Parameter(Mandatory)]
        [ValidateSet("Information","Warning","Error")]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        # Assume log + source already exist (created at install time)
        Write-EventLog `
            -LogName  $Global:FirewallEventLogName `
            -Source   $Global:FirewallEventSource `
            -EventId  $EventId `
            -EntryType $Type `
            -Message  $Message
    }
    catch {
        # Logging must NEVER break enforcement
        try {
            $fallback = "[$(Get-Date -Format o)] EVENTLOG FAILURE: $EventId | $Type | $Message"
            Add-Content -Path "C:\Firewall\Logs\EventLog-Fallback.log" -Value $fallback
        } catch { }
    }
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDWYBmV0eY2zNnB
# P30aV+RNOEAgVNJd1t1BzQIzcmpaF6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ILXU3q4J5ntmUqkjGwPVlY5Hz5+B4cD6QxxCjfRSYqJnMAsGByqGSM49AgEFAARI
# MEYCIQDRoRnlLCElvhuRsDM9qGP0HN2rts4ThiPRYuVya05jCQIhAISlRS6s3tyK
# +un9tNdSD7V4G5VaC5PEazBdvPceqmg+
# SIG # End signature block
