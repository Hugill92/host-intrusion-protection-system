# FirewallCore shim (compat path). Do not edit business logic here.
# Real implementation:
#   Tools\Notifiers\Patch-FirewallNotifier.ps1

$ErrorActionPreference = 'Stop'
& (Join-Path -Path "" -ChildPath "Tools\Notifiers\Patch-FirewallNotifier.ps1") @args
