$FirewallRoot = "C:\FirewallInstaller\Firewall"
$flag = Join-Path $FirewallRoot "State\Baseline\allow_update.flag"

New-Item (Split-Path $flag) -ItemType Directory -Force | Out-Null
"ALLOW $(Get-Date -Format o)" | Set-Content -Path $flag -Encoding ASCII
