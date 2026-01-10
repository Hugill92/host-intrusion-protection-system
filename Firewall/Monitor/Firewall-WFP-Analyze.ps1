$cfg = Get-Content "C:\Firewall\State\wfp.config.json" | ConvertFrom-Json
$statePath = "C:\Firewall\State\wfp.state.json"

$since = (Get-Date).AddSeconds(-$cfg.windowSeconds)

$events = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 5157
    StartTime = $since
} -ErrorAction SilentlyContinue

$groups = $events | Group-Object {
    ($_.Properties[5].Value) + "|" + ($_.Properties[18].Value)
}

foreach ($g in $groups) {
    $count = $g.Count
    $parts = $g.Name -split '\|'
    $proc  = $parts[0]
    $ip    = $parts[1]

    if ($cfg.allowProcesses -contains $proc) { continue }

    if ($count -ge $cfg.beaconThreshold) {
        Write-EventLog -LogName Firewall `
            -Source Firewall-WFP `
            -EventId 4101 `
            -EntryType Warning `
            -Message "WFP beacon-like activity detected. Process=$proc RemoteIP=$ip Count=$count Window=$($cfg.windowSeconds)s"
    }
}
