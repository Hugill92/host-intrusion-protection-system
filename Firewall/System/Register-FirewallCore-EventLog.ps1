$log = "FirewallCore"
$sources = @("FirewallCore","FirewallCore-Pentest")

if (-not [System.Diagnostics.EventLog]::Exists($log)) {
    New-EventLog -LogName $log -Source $sources[0]
}

foreach ($s in $sources) {
    if (-not [System.Diagnostics.EventLog]::SourceExists($s)) {
        New-EventLog -LogName $log -Source $s
    }
}

Write-Host "[OK] FirewallCore log ready"
