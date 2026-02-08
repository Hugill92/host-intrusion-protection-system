# FirewallCore shim (compat path). Do not edit business logic here.
# Keeps stable call sites while Modules are reorganized.
# Real implementation:
#   C:\FirewallInstaller\Firewall\Modules\Diff\Diff-FirewallSnapshots.ps1

$ErrorActionPreference = 'Stop'
& 'C:\FirewallInstaller\Firewall\Modules\Diff\Diff-FirewallSnapshots.ps1' @args
