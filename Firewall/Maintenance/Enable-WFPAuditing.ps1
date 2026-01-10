[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Log($m) { Write-Host "[WFP-AUDIT] $m" }

$targets = @(
    "Filtering Platform Connection",
    "Filtering Platform Packet Drop"
)

foreach ($t in $targets) {
    try {
        $current = auditpol /get /subcategory:"$t" 2>$null

        if ($current -match "No Auditing") {
            Log "Enabling audit subcategory: $t"
            auditpol /set /subcategory:"$t" /success:enable /failure:enable | Out-Null
            Log "$t enabled"
        }
        else {
            Log "$t already enabled"
        }
    }
    catch {
        Log "Could not modify audit policy for '$t' (likely Group Policy enforced)"
    }
}
