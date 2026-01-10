Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$FirewallRoot = "C:\FirewallInstaller\Firewall"
$Pending = Join-Path $FirewallRoot "State\NotifyQueue\Pending"

$windowSeconds = 10
$now = Get-Date

$files = Get-ChildItem $Pending -Filter *.json -ErrorAction SilentlyContinue
if ($files.Count -le 1) { return }

$items = foreach ($f in $files) {
    $d = Get-Content $f.FullName -Raw | ConvertFrom-Json
    [pscustomobject]@{
        File = $f
        Time = [datetime]$d.Time
        Severity = $d.Severity
        Title = $d.Title
        TestId = $d.TestId
    }
}

$recent = $items | Where-Object {
    ($now - $_.Time).TotalSeconds -le $windowSeconds
}

if ($recent.Count -gt 1) {
    $summary = @{
        Count     = $recent.Count
        Severity  = ($recent | Sort-Object Severity -Descending | Select-Object -First 1).Severity
        TestIds   = ($recent.TestId | Sort-Object -Unique)
        Titles    = ($recent.Title | Sort-Object -Unique)
    }

    $out = @{
        Time     = (Get-Date).ToString("o")
        Severity = $summary.Severity
        Title    = "[AGGREGATED ALERT] $($summary.Count) events detected"
        Message  = "Multiple related alerts detected within $windowSeconds seconds.`n`nTestIds:`n$($summary.TestIds -join "`n")"
        Notify   = @("Popup","Event")
        TestId   = "AGGREGATED"
    } | ConvertTo-Json -Depth 6

    $file = Join-Path $Pending ("notify_aggregate_{0}.json" -f ([guid]::NewGuid()))
    Set-Content -Path $file -Value $out -Encoding UTF8
}
