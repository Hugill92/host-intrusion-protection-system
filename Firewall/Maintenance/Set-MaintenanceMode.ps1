[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet("On","Off")][string]$Mode
)
$ErrorActionPreference="Stop"
function Assert-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Maintenance mode requires elevation (Admin)." }
}
Assert-Admin

$stateDir = "C:\ProgramData\FirewallCore"
$stateFile = Join-Path $stateDir "maintenance.json"
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

$enabled = ($Mode -eq "On")
$obj = [pscustomobject]@{
  Enabled = $enabled
  ChangedAt = (Get-Date).ToString("s")
  ChangedBy = $env:USERNAME
}
$obj | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $stateFile -Encoding UTF8

Write-Host ("[OK] Maintenance mode: {0}" -f ($(if($enabled){"ON"}else{"OFF"}))) -ForegroundColor Green
Write-Host ("State: {0}" -f $stateFile) -ForegroundColor Cyan

