# Wrapper (canonical script lives in _internal)
$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$canonical = Join-Path $repoRoot "_internal\InstallStage-EventViewerViews.ps1"
& $canonical @PSBoundParameters
