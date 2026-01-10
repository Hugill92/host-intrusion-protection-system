# ------------------------------------------------------------
# MATERIALIZE SYSTEM SCRIPTS (INTERNAL → INSTALLER TREE)
# ------------------------------------------------------------

$InternalSystemDir = Join-Path $InternalRoot "System"
$LiveSystemDir     = Join-Path $FirewallRoot "System"

New-Item -ItemType Directory -Path $LiveSystemDir -Force | Out-Null

$RequiredSystemScripts = @(
    "Register-FirewallCore-EventLog.ps1"
)

foreach ($script in $RequiredSystemScripts) {
    $src = Join-Path $InternalSystemDir $script
    $dst = Join-Path $LiveSystemDir     $script

    if (-not (Test-Path $src)) {
        throw "Installer missing required system script: $src"
    }

    Copy-Item $src $dst -Force
    Write-Host "[INSTALL] Materialized system script: $script"
}
