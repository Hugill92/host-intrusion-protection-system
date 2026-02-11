# FirewallCore shim (compat path). Do not edit business logic here.
# This file exists to keep scheduled tasks / callers stable while code is reorganized.
# Real implementation:
#   C:\FirewallInstaller\Firewall\Monitor\PolicyAudit\Firewall-Policy-Audit.ps1

$ErrorActionPreference = 'Stop'
& 'C:\FirewallInstaller\Firewall\Monitor\PolicyAudit\Firewall-Policy-Audit.ps1' @args
