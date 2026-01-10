# Firewall-SnapshotEvents.psm1
# Emits Event Viewer records for firewall snapshots + diffs
# DEV-safe, LIVE-safe, forensic-grade

Set-StrictMode -Version Latest

function Emit-FirewallSnapshotEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)]$Diff,
        [string]$RunId = ([guid]::NewGuid().ToString()),
        [ValidateSet("DEV","LIVE")]
        [string]$Mode = "LIVE"
    )

    # Defensive validation
    if (-not $Snapshot.Path -or -not $Snapshot.Hash) {
        return
    }

    $added    = $Diff.AddedCount
    $removed  = $Diff.RemovedCount
    $modified = $Diff.ModifiedCount

    $message = @"
Firewall snapshot diff detected.
Mode=$Mode
SnapshotHash=$($Snapshot.Hash)
RuleCount=$($Snapshot.RuleCount)
Added=$added
Removed=$removed
Modified=$modified
SnapshotFile=$($Snapshot.Path)
DiffFile=$($Diff.DiffPath)
RunId=$RunId
"@

    Write-FirewallEvent `
        -EventId 4100 `
        -Type Information `
        -Message $message
}

Export-ModuleMember -Function Emit-FirewallSnapshotEvent
