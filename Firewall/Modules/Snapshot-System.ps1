<#
Snapshot-System.ps1
Shared snapshot + diff utilities for Firewall Core installer/uninstaller.

Exports:
- Save-SystemSnapshot -Phase <string> -OutDir <path> [-Root <path>] [-InstallerRoot <path>] [-CertThumbprint <thumbprint>]
- Compare-SystemSnapshots -Before <file> -After <file> -OutFile <file>

Design:
- Human-readable text snapshot for audits and rollback safety checks.
- Includes a compact firewall-rule "fingerprint" (count + SHA256 of normalized rule lines)
  to support fast diffing without dumping every rule’s full XML.
#>

Set-StrictMode -Version Latest

function Get-FwRuleFingerprint {
    param([string]$PolicyStore = 'ActiveStore')

    try {
        $rules = Get-NetFirewallRule -PolicyStore $PolicyStore -ErrorAction Stop
    } catch {
        return [pscustomobject]@{ Count = -1; Sha256 = '<error>'; Error = $_.Exception.Message }
    }

    $lines = foreach ($r in $rules) {
        "{0}|{1}|{2}|{3}|{4}|{5}" -f $r.DisplayName, $r.Direction, $r.Action, $r.Enabled, $r.Profile, $r.Group
    }

    $sorted = $lines | Sort-Object
    $joined = ($sorted -join "`n")

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    $sha.Dispose()

    [pscustomobject]@{ Count = $lines.Count; Sha256 = $hash; Error = $null }
}

function Get-SchtasksLine {
    param([string]$TaskName)
    try {
        $out = & schtasks.exe /Query /TN $TaskName /V /FO LIST 2>$null
        if (-not $out) { return "$TaskName: missing" }
        $next = ($out | Select-String -Pattern '^Next Run Time:' -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -First 1)
        $last = ($out | Select-String -Pattern '^Last Run Time:' -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -First 1)
        $res  = ($out | Select-String -Pattern '^Last Result:' -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -First 1)
        return "$TaskName: present; $next; $last; $res"
    } catch {
        return "$TaskName: error ($($_.Exception.Message))"
    }
}

function Get-CertPresenceLine {
    param([string]$Thumbprint)
    if (-not $Thumbprint) { return "ScriptSigningCert: thumbprint not provided" }
    try {
        $c = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction Stop | Where-Object { $_.Thumbprint -eq $Thumbprint } | Select-Object -First 1
        if ($c) { return "ScriptSigningCert: present in LocalMachine\\Root ($Thumbprint)" }
        return "ScriptSigningCert: NOT present in LocalMachine\\Root ($Thumbprint)"
    } catch {
        return "ScriptSigningCert: error ($($_.Exception.Message))"
    }
}

function Save-SystemSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Phase,
        [Parameter(Mandatory)][string]$OutDir,
        [string]$Root = 'C:\Firewall',
        [string]$InstallerRoot = 'C:\FirewallInstaller',
        [string]$CertThumbprint = ''
    )

    $null = New-Item -ItemType Directory -Path $OutDir -Force -ErrorAction SilentlyContinue

    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $file = Join-Path $OutDir ("Snapshot-System-{0}-{1}.txt" -f $Phase, $ts)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("=== FIREWALL SNAPSHOT ===")
    $lines.Add("Phase: $Phase")
    $lines.Add("Timestamp: $(Get-Date -Format o)")
    $lines.Add("Computer: $env:COMPUTERNAME")
    $lines.Add("User: $env:USERNAME")
    $lines.Add("PSVersion: $($PSVersionTable.PSVersion)")
    $lines.Add("")

    $lines.Add("== Paths ==")
    $paths = @(
        $Root,
        (Join-Path $Root 'Monitor\Firewall-Core.ps1'),
        (Join-Path $Root 'Monitor\Firewall-WFP-Monitor.ps1'),
        (Join-Path $Root 'Golden\payload.manifest.sha256.json'),
        (Join-Path $Root 'State\baseline.json'),
        (Join-Path $Root 'State\wfp.config.json'),
        (Join-Path $InstallerRoot '_internal\Install-Firewall.ps1'),
        (Join-Path $InstallerRoot '_internal\Uninstall-Firewall.ps1')
    )

    foreach ($p in $paths) {
        try {
            if (Test-Path $p) { $lines.Add("$($p): present") }
            else { $lines.Add("$($p): missing") }
        } catch {
            $lines.Add("$($p): missing or inaccessible ($($_.Exception.Message))")
        }
    }
    $lines.Add("")

    $lines.Add("== Scheduled Tasks ==")
    $lines.Add((Get-SchtasksLine -TaskName 'Firewall Core Monitor'))
    $lines.Add((Get-SchtasksLine -TaskName 'Firewall WFP Monitor'))
    $lines.Add("")

    $lines.Add("== Execution Policy ==")
    try {
        $lines.Add("Effective: $(Get-ExecutionPolicy)")
        $lines.Add("LocalMachine: $(Get-ExecutionPolicy -Scope LocalMachine)")
        $lines.Add("CurrentUser: $(Get-ExecutionPolicy -Scope CurrentUser)")
        $lines.Add("Process: $(Get-ExecutionPolicy -Scope Process)")
    } catch {
        $lines.Add("ExecutionPolicy: error ($($_.Exception.Message))")
    }
    $lines.Add("")

    $lines.Add("== Firewall Rules Fingerprint ==")
    $fp = Get-FwRuleFingerprint
    $lines.Add("Count: $($fp.Count)")
    $lines.Add("Sha256: $($fp.Sha256)")
    if ($fp.Error) { $lines.Add("Error: $($fp.Error)") }
    $lines.Add("")

    $lines.Add("== Event Log Providers (Firewall log) ==")
    try {
        $lines.Add("Firewall-Core source exists: $([System.Diagnostics.EventLog]::SourceExists('Firewall-Core'))")
        $lines.Add("Firewall-WFP  source exists: $([System.Diagnostics.EventLog]::SourceExists('Firewall-WFP'))")
    } catch {
        $lines.Add("EventLog: error ($($_.Exception.Message))")
    }
    $lines.Add("")

    $lines.Add("== Certificate ==")
    $lines.Add((Get-CertPresenceLine -Thumbprint $CertThumbprint))
    $lines.Add("")

    $lines.Add("=== END SNAPSHOT ===")

    $lines -join "`r`n" | Set-Content -Path $file -Encoding UTF8
    return $file
}

function Compare-SystemSnapshots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Before,
        [Parameter(Mandatory)][string]$After,
        [Parameter(Mandatory)][string]$OutFile
    )
    $b = Get-Content -Path $Before -ErrorAction Stop
    $a = Get-Content -Path $After -ErrorAction Stop

    $diff = Compare-Object -ReferenceObject $b -DifferenceObject $a -PassThru

    $header = @(
        "=== SNAPSHOT DIFF ===",
        "Before: $Before",
        "After : $After",
        "Timestamp: $(Get-Date -Format o)",
        ""
    )

    ($header + $diff) -join "`r`n" | Set-Content -Path $OutFile -Encoding UTF8
    return $OutFile
}
Export-ModuleMember -Function Get-FirewallSnapshot
