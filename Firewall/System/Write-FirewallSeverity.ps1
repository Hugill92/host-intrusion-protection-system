param(
    [ValidateSet("LOW","MEDIUM","HIGH","CRITICAL")]
    [string]$Severity,

    [string]$Title,
    [string]$Details,

    [hashtable]$Context
)
$ToastScript = "C:\FirewallInstaller\Firewall\System\Show-FirewallToast.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$LogName = "FirewallCore"
$Source  = "FirewallCore.Live"

$EventId = switch ($Severity) {
    "LOW"      { 2000 }
    "MEDIUM"   { 2100 }
    "HIGH"     { 3000 }
    "CRITICAL" { 4000 }
}

if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
    New-EventLog -LogName $LogName -Source $Source
}

$Payload = @{
    Severity  = $Severity
    Title     = $Title
    Details   = $Details
    Context   = $Context
    User      = $env:USERNAME
    Host      = $env:COMPUTERNAME
    Timestamp = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 6

Write-EventLog `
    -LogName $LogName `
    -Source  $Source `
    -EventId $EventId `
    -EntryType Warning `
    -Message $Payload
	
	# Show toast for HIGH / CRITICAL only
if ($Severity -in @("HIGH","CRITICAL") -and (Test-Path $ToastScript)) {

    $toastTitle = "Firewall Alert: $Severity"
    $toastBody  = $Title

    try {
        & $ToastScript -Title $toastTitle -Body $toastBody
    }
    catch {
        # Toast failure must NEVER break detection
    }
}


# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDFdbCDDl+zzUDJ
# lPIJNcwWXw7Y7sIC4hgI8CxXjksssaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# IFHFvaPtHbyh9WICPQB9TDZuSH9khdctqGHukGp8KpsiMAsGByqGSM49AgEFAARG
# MEQCIGyHAZ67othLhLWwksVz4ckptqLxcRGgiUPrCzxJu+o+AiBO9dhSdBWzlkt6
# syP59ekBbeNnClUr5EHkehnDSoevSA==
# SIG # End signature block
