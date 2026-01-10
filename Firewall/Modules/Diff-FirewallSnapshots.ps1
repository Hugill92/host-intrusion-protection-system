param(
    [string]$SnapshotDir = "C:\Firewall\Snapshots",
    [string]$DiffDir     = "C:\Firewall\Diff"
)

New-Item -ItemType Directory -Path $DiffDir -Force | Out-Null

$files = Get-ChildItem $SnapshotDir -Filter "firewall_*.json" |
         Sort-Object LastWriteTime -Descending

if ($files.Count -lt 2) {
    Write-Output "[INFO] Not enough snapshots to diff"
    exit
}

$new = Get-Content $files[0] | ConvertFrom-Json
$old = Get-Content $files[1] | ConvertFrom-Json

$diff = Compare-Object $old $new `
    -Property Name,Enabled,Direction,Action,Profile,Program,LocalPort,RemotePort `
    -PassThru

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$diffFile = "$DiffDir\firewall_diff_$timestamp.json"

$diff | ConvertTo-Json -Depth 5 | Out-File $diffFile -Encoding UTF8

Write-Output "[OK] Firewall diff written to $diffFile"
