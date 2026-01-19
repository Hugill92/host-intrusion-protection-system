# ==========================================
# FIREWALL BOOTSTRAP (SELF-HEAL)
# ==========================================

$TaskName   = "Firewall Core Monitor"
$ScriptPath = "C:\Firewall\Monitor\Firewall-Core.ps1"

$Exists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

# --- FIX WMI FIREWALL PERMISSIONS ---
$ns = "root\standardcimv2"
$sd = Get-CimInstance -Namespace root\cimv2 -ClassName __SystemSecurity

$admins = "BUILTIN\Administrators"
$users  = "BUILTIN\Users"

# Reset to safe baseline
Invoke-CimMethod -InputObject $sd -MethodName SetSecurityDescriptor `
    -Arguments @{ Descriptor = (Get-CimInstance -Namespace root\cimv2 -ClassName Win32_SecurityDescriptor) }

# Admins = Full
$null = cmd /c "wmic /namespace:\\root\standardcimv2 path __systemsecurity call SetSecurityDescriptor `"D:(A;;CCDCLCSWRPWPRCWD;;;BA)(A;;CCLCSWLO;;;BU)`""


if (-not $Exists) {

    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    $Trigger.RepetitionInterval = (New-TimeSpan -Minutes 5)
    $Trigger.RepetitionDuration = (New-TimeSpan -Days 1)

    $Principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    $Settings = New-ScheduledTaskSettingsSet `
        -Hidden `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Force
}
