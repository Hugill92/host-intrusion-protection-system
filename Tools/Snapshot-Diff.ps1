[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Old,
  [Parameter(Mandatory)][string]$New,
  [string]$OutFile = "C:\FirewallInstaller\Tools\Snapshot-Diff.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Lines($p) { Get-Content -LiteralPath $p -ErrorAction Stop }

$oldLines = Get-Lines $Old
$newLines = Get-Lines $New

# Line diff (simple + reliable)
$diff = Compare-Object -ReferenceObject $oldLines -DifferenceObject $newLines -IncludeEqual:$false -PassThru |
  ForEach-Object { $_ }

New-Item -ItemType Directory -Path (Split-Path -Parent $OutFile) -Force | Out-Null

"Snapshot Diff" | Set-Content $OutFile
"OLD: $Old" | Add-Content $OutFile
"NEW: $New" | Add-Content $OutFile
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $OutFile
"" | Add-Content $OutFile

"==============================" | Add-Content $OutFile
"RAW LINE DIFF" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
$diff | Add-Content $OutFile

"" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
"NOTE" | Add-Content $OutFile
"==============================" | Add-Content $OutFile
"RAW LINE DIFF is blunt by design. Use it to verify tasks, rules, profile defaults, golden files, and signature changes." | Add-Content $OutFile

Write-Host "[OK] Wrote diff: $OutFile"
