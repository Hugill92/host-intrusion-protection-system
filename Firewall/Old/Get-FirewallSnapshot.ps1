# FirewallSnapshot.psm1
# Captures full Windows Firewall rule state

function Get-FirewallSnapshot {
    param(
        [string]$SnapshotDir = "C:\FirewallInstaller\Firewall\Snapshots"
    )

    if (-not (Test-Path $SnapshotDir)) {
        New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null
    }

    $timestamp    = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $snapshotFile = Join-Path $SnapshotDir "firewall_$timestamp.json"
    $latestFile   = Join-Path $SnapshotDir "latest.json"

    Write-Output "[SNAPSHOT] Capturing firewall rules"

    $rules = Get-NetFirewallRule | ForEach-Object {
        $r = $_

        $port = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
        $addr = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
        $app  = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Name        = $r.Name
            DisplayName = $r.DisplayName
            Group       = $r.Group
            Enabled     = $r.Enabled
            Direction   = $r.Direction
            Action      = $r.Action
            Profile     = $r.Profile
            Program     = $app.Program
            Protocol    = $port.Protocol
            LocalPort   = $port.LocalPort
            RemotePort  = $port.RemotePort
            LocalAddr   = $addr.LocalAddress
            RemoteAddr  = $addr.RemoteAddress
        }
    }

    $rules | ConvertTo-Json -Depth 6 | Out-File $snapshotFile -Encoding UTF8
    Copy-Item $snapshotFile $latestFile -Force

    Write-Output "[SNAPSHOT] Snapshot written: $snapshotFile"

    return $snapshotFile
}

Export-ModuleMember -Function Get-FirewallSnapshot
