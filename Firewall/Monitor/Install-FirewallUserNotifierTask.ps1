Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TaskName = "FirewallCore User Notifier"
$Script   = "C:\Firewall\Monitor\Firewall-UserNotifier.ps1"

if (-not (Test-Path $Script)) {
    throw "Notifier script not found: $Script"
}

# Remove existing task if present (idempotent)
Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

$Action  = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""

$Trigger = New-ScheduledTaskTrigger -AtLogOn

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "FirewallCore user notification service (dialogs only, v1)" `
    -RunLevel Highest `
    -Force | Out-Null

Write-Host "[OK] Scheduled task installed: $TaskName"
