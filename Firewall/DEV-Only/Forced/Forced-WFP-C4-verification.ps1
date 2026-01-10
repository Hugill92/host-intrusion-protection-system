param(
    [ValidateSet("DEV","LIVE")]
    [string]$Mode = "DEV"
)

Write-Host "Starting Forced-WFP-C4 test"

if ($Mode -ne "LIVE") {
    Write-Host "[FORCED-RESULT] SKIPPED"
    exit 0
}

# ---- Notification hook (v1, before exit) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop
    Send-FirewallNotification -Severity Critical -Title "WFP enforcement not active" -Message "LIVE WFP C4 validation failed - enforcement not wired." -Notify @("Popup","Event") -TestId "Forced-WFP-C4"
}
catch {
    # best-effort only
}

Write-Error "WFP C4 LIVE enforcement is not yet implemented."
Write-Host "[FORCED-RESULT] FAIL"
exit 1

# ---- v1 Notification Hook (import + call) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop

    Send-FirewallNotification `
        -Severity Critical `
        -Title "WFP enforcement not active" `
        -Message "LIVE WFP C4 validation failed ??? enforcement not wired." `
        -Notify @("Popup","Event") `
        -TestId "Forced-WFP-C4"
}
catch {
    # Notifications are best-effort only
}

# ---- v1 Notification Hook (import + call) ----
try {
    Import-Module "C:\FirewallInstaller\Firewall\Modules\FirewallNotifications.psm1" -Force -ErrorAction Stop

    Send-FirewallNotification `
        -Severity Critical `
        -Title "WFP enforcement not active" `
        -Message "LIVE WFP C4 validation failed ??? enforcement not wired." `
        -Notify @("Popup","Event") `
        -TestId "Forced-WFP-C4"
}
catch {
    # Notifications are best-effort only
}
