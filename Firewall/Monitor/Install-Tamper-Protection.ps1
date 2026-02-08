# FirewallCore shim (compat path). Do not edit business logic here.
# This file exists to keep scheduled tasks / callers stable while code is reorganized.
# Real implementation:
#   C:\FirewallInstaller\Firewall\Monitor\Tamper\Install-Tamper-Protection.ps1

$ErrorActionPreference = 'Stop'
& 'C:\FirewallInstaller\Firewall\Monitor\Tamper\Install-Tamper-Protection.ps1' @args
