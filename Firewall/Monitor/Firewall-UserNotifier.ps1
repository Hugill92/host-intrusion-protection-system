Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Notifier = "C:\Firewall\Monitor\Invoke-FirewallNotifier.ps1"
if (-not (Test-Path $Notifier)) { throw "Missing notifier script: $Notifier" }

while ($true) {
    try {
        & powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File $Notifier
    } catch {
        # never crash the wrapper
    }
    Start-Sleep -Seconds 2
}
