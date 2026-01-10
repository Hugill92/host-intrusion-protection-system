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
