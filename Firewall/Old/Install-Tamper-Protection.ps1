# ================= EXECUTION POLICY SELF-BYPASS =================
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Error "Constrained language mode detected. Exiting."
    exit 1
}

if ((Get-ExecutionPolicy -Scope Process) -ne 'Bypass') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath" @args
    exit $LASTEXITCODE
}
# =================================================================



$Action = New-ScheduledTaskAction `
  -Execute "powershell.exe" `
  -Argument '-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File "C:\Firewall\Monitor\Firewall-Tamper-Check.ps1"'

$Trigger = New-ScheduledTaskTrigger `
  -Once `
  -At (Get-Date) `
  -RepetitionInterval (New-TimeSpan -Minutes 10) `
  -RepetitionDuration (New-TimeSpan -Days 1)

$Settings = New-ScheduledTaskSettingsSet `
  -Hidden `
  -Compatibility Win8 `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Unregister-ScheduledTask -TaskName "Firewall Tamper Guard" -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
  -TaskName "Firewall Tamper Guard" `
  -Action $Action `
  -Trigger $Trigger `
  -Settings $Settings `
  -User "SYSTEM" `
  -RunLevel Highest
