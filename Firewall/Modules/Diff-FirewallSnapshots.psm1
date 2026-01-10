# Diff-FirewallSnapshots.psm1
# Forensic diff engine for firewall snapshots

Set-StrictMode -Version Latest

function Compare-FirewallSnapshots {
    [CmdletBinding()]
    param(
        [string]$SnapshotDir = "C:\Firewall\Snapshots",
        [string]$DiffDir     = "C:\Firewall\Diff"
    )

    if (!(Test-Path $SnapshotDir)) { return $null }
    if (!(Test-Path $DiffDir)) {
        New-Item -ItemType Directory -Path $DiffDir -Force | Out-Null
    }

    $snaps = Get-ChildItem $SnapshotDir -Filter "firewall_*.json" |
             Sort-Object LastWriteTime -Descending

    if ($snaps.Count -lt 2) { return $null }

    $newPath = $snaps[0].FullName
    $oldPath = $snaps[1].FullName

    $new = Get-Content $newPath -Raw | ConvertFrom-Json
    $old = Get-Content $oldPath -Raw | ConvertFrom-Json

    $newIdx = @{}; foreach ($r in $new) { if ($r.Name) { $newIdx[$r.Name] = $r } }
    $oldIdx = @{}; foreach ($r in $old) { if ($r.Name) { $oldIdx[$r.Name] = $r } }

    $added = @()
    $removed = @()
    $modified = @()

    foreach ($k in $newIdx.Keys) {
        if (-not $oldIdx.ContainsKey($k)) {
            $added += $newIdx[$k]
        }
        elseif ((ConvertTo-Json $newIdx[$k] -Depth 6) -ne (ConvertTo-Json $oldIdx[$k] -Depth 6)) {
            $modified += [pscustomobject]@{
                Name = $k
                Old  = $oldIdx[$k]
                New  = $newIdx[$k]
            }
        }
    }

    foreach ($k in $oldIdx.Keys) {
        if (-not $newIdx.ContainsKey($k)) {
            $removed += $oldIdx[$k]
        }
    }

    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $diffPath = Join-Path $DiffDir "firewall_diff_$ts.json"

    $diff = [pscustomobject]@{
        Timestamp     = (Get-Date).ToString("o")
        NewSnapshot   = $newPath
        OldSnapshot   = $oldPath
        DiffPath      = $diffPath
        AddedCount    = $added.Count
        RemovedCount  = $removed.Count
        ModifiedCount = $modified.Count
        Added         = $added
        Removed       = $removed
        Modified      = $modified
    }

    $diff | ConvertTo-Json -Depth 8 | Set-Content -Path $diffPath -Encoding UTF8
    return $diff
}

Export-ModuleMember -Function Compare-FirewallSnapshots
