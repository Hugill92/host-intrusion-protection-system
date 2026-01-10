param(
    [string]$SnapshotDir = "C:\Firewall\Snapshots"
)

New-Item -ItemType Directory -Path $SnapshotDir -Force | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$snapshotFile = "$SnapshotDir\firewall_$timestamp.json"
$latestFile   = "$SnapshotDir\latest.json"

$rules = Get-NetFirewallRule |
    ForEach-Object {
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
            LocalPort   = $port.LocalPort
            RemotePort  = $port.RemotePort
            LocalAddr   = $addr.LocalAddress
            RemoteAddr  = $addr.RemoteAddress
            Protocol    = $port.Protocol
        }
    }

$rules | ConvertTo-Json -Depth 5 | Out-File $snapshotFile -Encoding UTF8
Copy-Item $snapshotFile $latestFile -Force
