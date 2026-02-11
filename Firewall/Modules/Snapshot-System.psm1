# FirewallCore shim module (compat path). Do not edit business logic here.
# Keeps stable Import-Module paths while Modules are reorganized.
# Real implementation (relative to this file):
#   Snapshots\Snapshot-System.psm1

$ErrorActionPreference = 'Stop'
$real = Join-Path -Path $PSScriptRoot -ChildPath 'Snapshots\Snapshot-System.psm1'
if (-not (Test-Path -LiteralPath $real)) { throw ("Real module missing: {0}" -f $real) }
. $real
