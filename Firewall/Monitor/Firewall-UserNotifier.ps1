Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Notifier = "C:\Firewall\Monitor\Invoke-FirewallNotifier.ps1"
if (-not (Test-Path $Notifier)) { throw "Missing notifier script: $Notifier" }

while ($true) {
    try {
        & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File $Notifier
    } catch {
        # never crash the wrapper
    }
    Start-Sleep -Seconds 2
}
