# ------------------------------------------------------------
# Optional event writer shim (safe on clean machines)
# ------------------------------------------------------------
if (-not (Get-Command Write-FirewallEvent -ErrorAction SilentlyContinue)) {
    function Write-FirewallEvent {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [int]$EventId,

            [Parameter(Mandatory)]
            [ValidateSet('Information','Warning','Error')]
            [string]$Type,

            [Parameter(Mandatory)]
            [string]$Message
        )

        # DEV fallback: no event source yet
        Write-Verbose "[FIREWALL-EVENT:$EventId][$Type]"
        Write-Verbose $Message
    }
}


# Firewall-SnapshotEvents.psm1
# Snapshot → Event emission with severity escalation

Set-StrictMode -Version Latest

function Emit-FirewallSnapshotEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Snapshot,

        [Parameter(Mandatory)]
        $Diff,

        [ValidateSet("LIVE","DEV")]
        [string]$Mode = "LIVE",

        [string]$RunId = ([guid]::NewGuid().ToString())
    )

    # ======================================
    # Snapshot hash short-circuit
    # ======================================
    $historyFile = Join-Path $StateDir "snapshot.history.json"

    if (Test-Path $historyFile) {
        $history = Get-Content $historyFile -Raw | ConvertFrom-Json
        $last    = $history.Entries | Select-Object -Last 1

        if ($last.Hash -eq $Snapshot.Hash) {
            if ($Mode -eq "DEV") {
                Write-Host "[DEV] Snapshot hash unchanged — skipping event emission"
            }
            return
        }
    }

    if (-not $Snapshot -or -not $Diff) {
        return
    }

    # Normalize counts (defensive)
    $added = if ($Diff.PSObject.Properties['AddedCount'] -and $Diff.AddedCount -ne $null) {
    [int]$Diff.AddedCount
    } else { 0 }

    $removed = if ($Diff.PSObject.Properties['RemovedCount'] -and $Diff.RemovedCount -ne $null) {
        [int]$Diff.RemovedCount
    } else { 0 }

    $modified = if ($Diff.PSObject.Properties['ModifiedCount'] -and $Diff.ModifiedCount -ne $null) {
        [int]$Diff.ModifiedCount
    } else { 0 }


    # ======================================
    # Severity + Event ID selection  ✅
    # (YOUR BLOCK — correctly placed)
    # ======================================
    if ($added -gt 0 -or $removed -gt 0) {
        $eventId = 4102
        $level   = "Error"
    }
    elseif ($modified -gt 0) {
        $eventId = 4101
        $level   = "Warning"
    }
    else {
        $eventId = 4100
        $level   = "Information"
    }

    # ======================================
    # Forensic-grade message
    # ======================================
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
        -EventId $eventId `
        -Type    $level `
        -Message $message

    if ($Mode -eq "DEV") {
        Write-Host "[DEV] Snapshot events emitted (4100/4101/4102 as applicable)"
    }
}

Export-ModuleMember -Function Emit-FirewallSnapshotEvent
