# Firewall-SnapshotHistory.psm1
# Append-only snapshot hash history for forensic timelines

Set-StrictMode -Version Latest

$HistoryPath = "C:\Firewall\State\snapshot.history.jsonl"

function Write-SnapshotHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)]$Diff,
        [string]$RunId = "Unknown"
    )

    if (-not (Test-Path (Split-Path $HistoryPath))) {
        New-Item -ItemType Directory -Path (Split-Path $HistoryPath) -Force | Out-Null
    }

    $entry = [pscustomobject]@{
        ts            = (Get-Date).ToString("o")
        runId         = $RunId
        snapshotHash  = $Snapshot.Hash
        ruleCount     = $Snapshot.RuleCount
        snapshotPath  = $Snapshot.Path
        diffPath      = $Diff.DiffPath
        added         = $Diff.AddedCount
        removed       = $Diff.RemovedCount
        modified      = $Diff.ModifiedCount
        mode          = $Snapshot.Mode
        computer      = $env:COMPUTERNAME
    }

    # JSONL = append-only forensic log
    ($entry | ConvertTo-Json -Depth 5 -Compress) |
        Add-Content -Path $HistoryPath -Encoding UTF8
}

Export-ModuleMember -Function Write-SnapshotHistory
