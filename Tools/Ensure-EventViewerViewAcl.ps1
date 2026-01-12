[CmdletBinding()]
param(
  [string[]] $ViewDirs = @(
    (Join-Path $env:ProgramData "Microsoft\Event Viewer\Views"),
    (Join-Path $env:ProgramData "FirewallCore\User\Views")
  ),
  [string] $Principal = "BUILTIN\Users",
  [string] $Pattern = "FirewallCore*.xml",
  [switch] $Strict
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$m){ Write-Host $m -ForegroundColor Cyan }
function Write-Warn([string]$m){ Write-Host $m -ForegroundColor Yellow }
function Write-Ok([string]$m){ Write-Host $m -ForegroundColor Green }
function Write-Fail([string]$m){ Write-Host $m -ForegroundColor Red }

$anyFail = $false

foreach ($dir in $ViewDirs) {
  Write-Info "=== Ensure ACL: $dir ==="

  if (!(Test-Path -LiteralPath $dir)) {
    Write-Warn "SKIP: missing dir: $dir"
    continue
  }

  $files = Get-ChildItem -LiteralPath $dir -File -Filter $Pattern -ErrorAction Stop
  if (!$files -or $files.Count -eq 0) {
    Write-Warn "No matches for $Pattern in $dir"
    continue
  }

  foreach ($f in $files) {
    try {
      & icacls $f.FullName /grant "${Principal}:(R)" | Out-Null
      Write-Ok ("OK  : {0}" -f $f.Name)
    }
    catch {
      $anyFail = $true
      Write-Fail ("FAIL: {0} :: {1}" -f $f.FullName, $_.Exception.Message)
      if ($Strict) { throw }
    }
  }
}

if ($anyFail -and $Strict) { throw "One or more ACL updates failed." }

if ($anyFail) { Write-Warn "DONE with failures (non-strict)." }
else { Write-Ok "DONE: all ACL updates succeeded." }
