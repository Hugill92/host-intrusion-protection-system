# Firewall-SignatureGuard.psm1
# Verifies Authenticode signatures (tamper detection)

Set-StrictMode -Version Latest

function Test-FirewallScriptSignatures {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,

        [switch]$EmitEvents
    )

    $violations = @()

    $files = Get-ChildItem $RootPath -Recurse -Include *.ps1,*.psm1 -File |
        Where-Object {
            $_.FullName -notmatch '\\Old\\'
        }

    foreach ($file in $files) {
        $sig = Get-AuthenticodeSignature $file.FullName

        if ($sig.Status -ne 'Valid') {
            $violations += [pscustomobject]@{
                Path   = $file.FullName
                Status = $sig.Status
            }
        }
    }

    if ($EmitEvents -and $violations.Count -gt 0) {
        foreach ($v in $violations) {
            Write-FirewallEvent `
                -EventId 4201 `
                -Type Error `
                -Message "Script signature violation detected. Path=$($v.Path) Status=$($v.Status)"
        }
    }

    return $violations
}

Export-ModuleMember -Function Test-FirewallScriptSignatures
