Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ProgramRoot  = Join-Path $env:ProgramData "FirewallCore"
$script:QueueRoot    = Join-Path $script:ProgramRoot "NotifyQueue"
$script:QueuePending = Join-Path $script:QueueRoot "Pending"

$script:EventSource  = "FirewallCore"
$script:EventLogName = "FirewallCore"

function Ensure-Dirs {
    foreach ($d in @($script:ProgramRoot,$script:QueueRoot,$script:QueuePending)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

function Ensure-EventSource {
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventSource)) {
            New-EventLog -LogName $script:EventLogName -Source $script:EventSource | Out-Null
        }
    } catch {}
}

function New-EventId {
    param([ValidateSet('Info','Warning','Critical')] [string]$Severity)
    switch ($Severity) {
        'Info'     { 1001 }
        'Warning'  { 2001 }
        'Critical' { 3001 }
    }
}

function Write-FirewallEvent {
    param(
        [ValidateSet('Info','Warning','Critical')] [string]$Severity,
        [string]$Title,
        [string]$Message,
        [string]$TestId
    )
    Ensure-EventSource
    $eid = New-EventId -Severity $Severity
    $etype = switch ($Severity) {
        'Info'     { [System.Diagnostics.EventLogEntryType]::Information }
        'Warning'  { [System.Diagnostics.EventLogEntryType]::Warning }
        'Critical' { [System.Diagnostics.EventLogEntryType]::Error }
    }

    $text = "$Title`r`n$Message"
    if ($TestId) { $text += "`r`nTestId: $TestId" }

    try {
        Write-EventLog -LogName $script:EventLogName -Source $script:EventSource -EventId $eid -EntryType $etype -Message $text
    } catch {}

    return $eid
}

function New-NotificationPayload {
    param(
        [ValidateSet('Info','Warning','Critical')] [string]$Severity,
        [string]$Title,
        [string]$Message,
        [int]$EventId,
        [string]$TestId,
        [ValidateSet('Dev','Forced','Pentest','Live')] [string]$Mode = 'Dev'
    )

    [pscustomobject]@{
        SchemaVer  = 1
        CreatedUtc = (Get-Date).ToUniversalTime().ToString("o")
        Severity   = $Severity
        Title      = $Title
        Message    = $Message
        EventId    = $EventId
        TestId     = $TestId
        Provider   = 'FirewallCore'
        Mode       = $Mode
        Host       = $env:COMPUTERNAME
        User       = ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    }
}

function Enqueue-FirewallNotification {
    param([Parameter(Mandatory)] [psobject]$Payload)

    Ensure-Dirs
    $id = [guid]::NewGuid().ToString("n")
    $path = Join-Path $script:QueuePending ("{0}.json" -f $id)
    $Payload | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8 -Force
    return $path
}

function Send-FirewallNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Info','Warning','Critical')] [string]$Severity,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message,
        [string]$TestId,
        [ValidateSet('Dev','Forced','Pentest','Live')] [string]$Mode = 'Dev'
    )

    $eid = Write-FirewallEvent -Severity $Severity -Title $Title -Message $Message -TestId $TestId

    $payload = New-NotificationPayload -Severity $Severity -Title $Title -Message $Message -EventId $eid -TestId $TestId -Mode $Mode
    Enqueue-FirewallNotification -Payload $payload | Out-Null
    return $payload
}

Export-ModuleMember -Function Send-FirewallNotification, Enqueue-FirewallNotification, New-NotificationPayload, Write-FirewallEvent, New-EventId

# SIG # Begin signature block
# MIIEkwYJKoZIhvcNAQcCoIIEhDCCBIACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCPqD6c7PC/ef/n
# JClyzOWqZw6uP/PA5qU+WsVN/CuM/qCCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ICLp3aRdswu6Kho7bfwPjrdie3MubbUEL489+1cGxZQVMAsGByqGSM49AgEFAARH
# MEUCICorLzXQL3zqeOUo6r0HwKP8FljLvWO8mgN1cFRRcsDTAiEAidlWMfshR02K
# gypbWSU/i005LBur15ehyw4hnBJF+hA=
# SIG # End signature block
