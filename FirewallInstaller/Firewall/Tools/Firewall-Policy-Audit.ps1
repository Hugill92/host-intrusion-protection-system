Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "C:\Firewall\Modules\Firewall-EventLog.ps1"

# Look back 10 minutes for policy changes
$start = (Get-Date).AddMinutes(-10)

# These event IDs commonly record firewall policy/rule changes.
# We'll pull a set and log what we find.
$ids = @(4946,4947,4948,4950,4951,4952,4953,4954,4956,4957,4958)

$events = Get-WinEvent -FilterHashtable @{
    LogName   = "Security"
    Id        = $ids
    StartTime = $start
} -ErrorAction SilentlyContinue

if (-not $events) { exit 0 }

foreach ($e in $events) {
    $msg = $e.Message

    # Best-effort parse: account + rule name usually appears in the message text.
    $account = ""
    $rule    = ""

    if ($msg -match "Account Name:\s+([^\r\n]+)") { $account = $Matches[1].Trim() }
    if ($msg -match "Rule Name:\s+([^\r\n]+)")    { $rule    = $Matches[1].Trim() }

    $safe = "Firewall policy change detected. EventId=$($e.Id). Account='$account'. Rule='$rule'."
    Write-FirewallEvent -EventId 9300 -Type Information -Message $safe
}

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBrQXk2OghORhiz
# wJZGVtfcXjrbNAex6NEa0TRxtnAABaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IBczIYgsdBOrPi1nQen2O5ADTrZu1jvX/LYNwXCV2DlPMAsGByqGSM49AgEFAARG
# MEQCIBhhRMka2DGVHLpah0vdcIP0QBDoKZ7fOXEIJBi0lefuAiA8gVmbjxKzqAOv
# yGeyESVbIJ1RNzdsyoTSypqbLBHjzQ==
# SIG # End signature block
