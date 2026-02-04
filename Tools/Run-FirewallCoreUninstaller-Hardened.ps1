param()

$ErrorActionPreference = "Stop"
$cmd = Join-Path $PSScriptRoot "Run-FirewallCoreUninstaller-Hardened.cmd"
if (-not (Test-Path $cmd)) { throw "Missing: $cmd" }

& cmd.exe /c "`"$cmd`""
exit $LASTEXITCODE
