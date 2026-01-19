$FirewallRoot = "C:\FirewallInstaller\Firewall"
$flag = Join-Path $FirewallRoot "State\Baseline\allow_update.flag"
$baselineScript = Join-Path $FirewallRoot "Monitor\New-FirewallBaseline.ps1"

# No trust flag = no auto update
if (-not (Test-Path $flag)) { exit 0 }

# Trust window expires after 10 minutes
$ageMin = ((Get-Date).ToUniversalTime() - (Get-Item $flag).LastWriteTimeUtc).TotalMinutes
if ($ageMin -gt 10) {
    Remove-Item $flag -Force -ErrorAction SilentlyContinue
    exit 0
}

# Regenerate baseline
if (Test-Path $baselineScript) {
    powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $baselineScript -Quiet | Out-Null
}

# Consume trust flag
Remove-Item $flag -Force -ErrorAction SilentlyContinue
