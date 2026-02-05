Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$FirewallRoot = "C:\FirewallInstaller\Firewall"
$Pending = Join-Path $FirewallRoot "State\NotifyQueue\Pending"

$windowSeconds = 10
$now = Get-Date

$files = Get-ChildItem $Pending -Filter *.json -ErrorAction SilentlyContinue
if ($files.Count -le 1) { return }

$items = foreach ($f in $files) {
    $d = Get-Content $f.FullName -Raw | ConvertFrom-Json
    [pscustomobject]@{
        File = $f
        Time = [datetime]$d.Time
        Severity = $d.Severity
        Title = $d.Title
        TestId = $d.TestId
    }
}

$recent = $items | Where-Object {
    ($now - $_.Time).TotalSeconds -le $windowSeconds
}

if ($recent.Count -gt 1) {
    $summary = @{
        Count     = $recent.Count
        Severity  = ($recent | Sort-Object Severity -Descending | Select-Object -First 1).Severity
        TestIds   = ($recent.TestId | Sort-Object -Unique)
        Titles    = ($recent.Title | Sort-Object -Unique)
    }

    $out = @{
        Time     = (Get-Date).ToString("o")
        Severity = $summary.Severity
        Title    = "[AGGREGATED ALERT] $($summary.Count) events detected"
        Message  = "Multiple related alerts detected within $windowSeconds seconds.`n`nTestIds:`n$($summary.TestIds -join "`n")"
        Notify   = @("Popup","Event")
        TestId   = "AGGREGATED"
    } | ConvertTo-Json -Depth 6

    $file = Join-Path $Pending ("notify_aggregate_{0}.json" -f ([guid]::NewGuid()))
    Set-Content -Path $file -Value $out -Encoding UTF8
}

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD9Np5tyXRYY3S3
# 977wFWmNNol9CmlesG1kkg0zoMTBr6CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IAK9RHqZE+M+kCAB5hwAuyOXHH0PYOMt0Vj81PX4X1TiMAsGByqGSM49AgEFAARH
# MEUCIQCP0NO3rWrVj9IyJWJAL59v1TLgP7+snWm1BkiQlqjl/gIgXiCl2lC8CHzx
# mxN8lMmukOIPl35K1ysKaQMb8//HdSc=
# SIG # End signature block
