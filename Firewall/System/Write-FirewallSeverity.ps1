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

