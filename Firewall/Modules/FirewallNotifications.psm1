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
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUxBzWs/mNNXUeVPPlVEicikvo
# duugggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUjX4J4Suu3+ZeTf2x+oX78PieCOowCwYH
# KoZIzj0CAQUABEcwRQIhAPyByBunhKoX0wArUUDyfh6HoICM4RJW4vV1nn+xonQN
# AiByLdi68fR9LzKxG2mRBOlYFFvi9quBBrYRurof3WPRUA==
# SIG # End signature block
