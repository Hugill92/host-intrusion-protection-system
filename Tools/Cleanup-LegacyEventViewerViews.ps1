[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$NameRegex = '^View_\d+$',

  [string[]]$Roots = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Event Viewer\Views")
  ),

  [string]$ArchiveRoot = (Join-Path $env:ProgramData ("FirewallCore\Logs\ViewArchive\{0:yyyyMMdd_HHmmss}" -f (Get-Date)))
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Path $ArchiveRoot -Force | Out-Null
Write-Host "Archive: $ArchiveRoot" -ForegroundColor DarkGray

$deleted = 0
$kept    = 0

foreach ($root in $Roots) {
  if (!(Test-Path -LiteralPath $root)) { continue }

  Write-Host "`nSCAN: $root" -ForegroundColor Cyan
  $xmls = Get-ChildItem -LiteralPath $root -File -Filter *.xml -ErrorAction SilentlyContinue
  foreach ($f in $xmls) {
    $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (!$raw) { $kept++; continue }

    # Match either Name or DisplayName
    $m1 = [regex]::Match($raw, '<Name>\s*([^<]+)\s*</Name>', 'IgnoreCase')
    $m2 = [regex]::Match($raw, '<DisplayName>\s*([^<]+)\s*</DisplayName>', 'IgnoreCase')

    $name = $null
    if ($m2.Success) { $name = $m2.Groups[1].Value.Trim() }
    elseif ($m1.Success) { $name = $m1.Groups[1].Value.Trim() }

    if ($name -and ($name -match $NameRegex)) {
      $dest = Join-Path $ArchiveRoot $f.Name
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force

      if ($PSCmdlet.ShouldProcess($f.FullName, "Delete custom view '$name'")) {
        Remove-Item -LiteralPath $f.FullName -Force
        Write-Host "DELETE: $name  ($($f.Name))" -ForegroundColor Yellow
        $deleted++
      }
    } else {
      $kept++
    }
  }
}

Write-Host "`nDONE. Deleted: $deleted  Kept: $kept" -ForegroundColor Green
