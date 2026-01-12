# FirewallToastWatchdog.ps1
# Runs as SYSTEM every minute. Ensures the USER toast listener task is running and healthy.
# Health is determined by heartbeat file freshness.
$ErrorActionPreference = "SilentlyContinue"

$UserTaskName = "FirewallCore Toast Listener"
$Heartbeat    = Join-Path $env:ProgramData "FirewallCore\State\toastlistener.heartbeat"
$MaxAgeSec    = 60

function Heartbeat-IsFresh {
    param([string]$Path, [int]$MaxAgeSeconds)
    try {
        if (-not (Test-Path $Path)) { return $false }
        $age = ([DateTime]::UtcNow - (Get-Item $Path).LastWriteTimeUtc).TotalSeconds
        return ($age -le $MaxAgeSeconds)
    } catch { return $false }
}

# Check scheduled task state (best-effort)
$task = Get-ScheduledTask -TaskName $UserTaskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
    # Nothing to do; installer should create it. Keep silent.
    exit 0
}

$fresh = Heartbeat-IsFresh -Path $Heartbeat -MaxAgeSeconds $MaxAgeSec
if ($fresh) {
    exit 0
}

# If heartbeat stale or missing, restart the user task
try { Stop-ScheduledTask -TaskName $UserTaskName -ErrorAction SilentlyContinue | Out-Null } catch {}
Start-ScheduledTask -TaskName $UserTaskName | Out-Null
