param(
    [ValidateSet("LOW","MEDIUM","HIGH","CRITICAL")]
    [string]$Severity,

    [string]$Title,
    [string]$Details,

    [hashtable]$Context
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$logName   = "FirewallCore"
$source    = "FirewallCore.Live"
$eventId   = switch ($Severity) {
    "LOW"      { 2000 }
    "MEDIUM"   { 2100 }
    "HIGH"     { 3000 }
    "CRITICAL" { 4000 }
}

# Ensure event source exists
if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
    New-EventLog -LogName $logName -Source $source
}

$payload = @{
    Severity  = $Severity
    Title     = $Title
    Details   = $Details
    Context   = $Context
    Timestamp = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 6

Write-EventLog `
    -LogName $logName `
    -Source $source `
    -EventId $eventId `
    -EntryType Warning `
    -Message $payload
