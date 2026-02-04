param()

$ErrorActionPreference = "Stop"
$cmd = Join-Path $PSScriptRoot "Run-FirewallCoreInstaller-Hardened.cmd"
if (-not (Test-Path $cmd)) { throw "Missing: $cmd" }

& cmd.exe /c "`"$cmd`""
exit $LASTEXITCODE
