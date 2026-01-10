. "C:\Firewall\Modules\WFP-Actions.ps1"

Invoke-HostIsolationNow -AllowDHCP -AllowDNS -AllowRDPFromLocalSubnet:$false -AllowWinRMFromLocalSubnet:$false
Write-Host "[OK] Host isolation enabled (defaults are block in/out)."
