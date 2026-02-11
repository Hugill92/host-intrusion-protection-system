# Run once (admin)
$dirs = @(
  "C:\Firewall\Logs\Operational",
  "C:\Firewall\Logs\Debug",
  "C:\Firewall\Logs\PenTest",
  "C:\Firewall\Logs\Events",
  "C:\Firewall\Modules",
  "C:\Firewall\Monitor\Notifier",
  "$env:ProgramData\FirewallCore\NotifyQueue\Pending",
  "$env:ProgramData\FirewallCore\NotifyQueue\Processed",
  "$env:ProgramData\FirewallCore\NotifyQueue\Failed",
  "$env:ProgramData\FirewallCore\State"
)
$dirs | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
