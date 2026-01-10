Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Snapshot history persistence (SAFE, ARRAY-STABLE)
# ------------------------------------------------------------
function Add-SnapshotHistoryEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Snapshot,

        [Parameter(Mandatory)]
        [string]$StateDir
    )

    if (-not (Test-Path $StateDir)) {
        New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    }

    $historyPath = Join-Path $StateDir 'snapshot-history.json'
    $history = @()

    if (Test-Path $historyPath) {
        try {
            $loaded = Get-Content $historyPath -Raw | ConvertFrom-Json
            if ($loaded) {
                $history = @($loaded)   # FORCE ARRAY
            }
        }
        catch {
            $history = @()
        }
    }

    # SAFE append (NO op_Addition)
    $history += $Snapshot

    $history |
        ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath $historyPath -Encoding UTF8
}

# ------------------------------------------------------------
# Firewall snapshot (DETERMINISTIC + FAST-SAFE)
# ------------------------------------------------------------
function Get-FirewallSnapshot {
    [CmdletBinding()]
    param(
        [string]$SnapshotDir = "C:\Firewall\Snapshots",
        [string]$StateDir,
        [switch]$Fast
    )

    $ProgressPreference = "SilentlyContinue"

    if (-not (Test-Path $SnapshotDir)) {
        New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null
    }
    if ($StateDir -and -not (Test-Path $StateDir)) {
        New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    }

    $runId     = [guid]::NewGuid().ToString()
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $path      = Join-Path $SnapshotDir ("firewall_{0}.json" -f $timestamp)

    # EAGER + ORDERED materialization
    $rulesRaw = Get-NetFirewallRule -PolicyStore PersistentStore |
        Sort-Object Name |
        Select-Object `
            Name,
            DisplayName,
            Group,
            Enabled,
            Direction,
            Action,
            Profile,
            EdgeTraversalPolicy,
            Owner

    $rules = foreach ($r in $rulesRaw) {
        [pscustomobject][ordered]@{
            Name        = $r.Name
            DisplayName = $r.DisplayName
            Group       = $r.Group
            Enabled     = [bool]$r.Enabled
            Direction   = [string]$r.Direction
            Action      = [string]$r.Action
            Profile     = [string]$r.Profile
            Edge        = [string]$r.EdgeTraversalPolicy
            Owner       = $r.Owner

            # Stable schema (never null arrays)
            Program     = $null
            Service     = $null
            Protocol    = $null
            LocalPort   = @()
            RemotePort  = @()
            LocalAddr   = @()
            RemoteAddr  = @()
            Interface   = @()
        }
    }

    # CANONICAL JSON (in-memory)
    $json = $rules | ConvertTo-Json -Depth 6 -Compress

    # STABLE HASH (order + content deterministic)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $hash  = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
    }
    finally {
        $sha.Dispose()
    }

    # ATOMIC WRITE
    $tmp = "$path.tmp"
    [System.IO.File]::WriteAllText($tmp, $json, [System.Text.Encoding]::UTF8)
    Move-Item -LiteralPath $tmp -Destination $path -Force

    $snapshot = [pscustomobject]@{
        Path      = $path
        Hash      = $hash
        RuleCount = $rules.Count
        Timestamp = (Get-Date).ToString("o")
        Mode      = "Fast"
        RunId     = $runId
    }

    if ($StateDir) {
        Add-SnapshotHistoryEntry -Snapshot $snapshot -StateDir $StateDir
    }

    return $snapshot
}

# ------------------------------------------------------------
# EXPORTS
# ------------------------------------------------------------
Export-ModuleMember -Function `
    Get-FirewallSnapshot, `
    Add-SnapshotHistoryEntry
