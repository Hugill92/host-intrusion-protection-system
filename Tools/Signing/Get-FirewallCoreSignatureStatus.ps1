param(
  [string]$Root = 'C:\FirewallInstaller'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "`n=== SIGNATURE STATUS (locked-safe) ===" -ForegroundColor Cyan
Write-Host ("[INFO] Root: {0}" -f $Root) -ForegroundColor Cyan

$files = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop |
  Where-Object { $_.Extension -in '.ps1','.psm1','.psd1' }

$rows = foreach ($f in $files) {
  try {
    $s = Get-AuthenticodeSignature -FilePath $f.FullName -ErrorAction Stop
    [pscustomobject]@{ Status = $s.Status; Path = $f.FullName }
  } catch {
    $msg = ($_.Exception.Message + '')
    if ($msg -match 'cannot access the file|being used by another process') {
      [pscustomobject]@{ Status = 'LOCKED'; Path = $f.FullName }
    } else {
      [pscustomobject]@{ Status = 'ERROR'; Path = $f.FullName }
    }
  }
}

$rows | Group-Object Status | Sort-Object Count -Descending | Format-Table Count,Name -AutoSize

Write-Host "`n[INFO] To list LOCKED/ERROR paths:" -ForegroundColor Cyan
Write-Host "  `$rows | ? Status -in 'LOCKED','ERROR' | % Path" -ForegroundColor Cyan
