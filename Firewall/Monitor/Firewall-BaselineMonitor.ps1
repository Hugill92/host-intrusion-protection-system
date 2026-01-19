$FirewallRoot = "C:\FirewallInstaller\Firewall"

Import-Module "$FirewallRoot\Modules\FirewallDetection.psm1" -Force
Import-Module "$FirewallRoot\Modules\FirewallNotifications.psm1" -Force

$SelfHealScript   = Join-Path $FirewallRoot "Monitor\Firewall-SelfHeal.ps1"
$AutoUpdateScript = Join-Path $FirewallRoot "Monitor\AutoUpdate-FirewallBaseline.ps1"
$AllowFlag        = Join-Path $FirewallRoot "State\Baseline\allow_update.flag"

function Notify($Severity,$Title,$Message,$TestId) {
    try {
        Send-FirewallNotification `
            -Severity $Severity `
            -Title $Title `
            -Message $Message `
            -Notify @("Popup","Event") `
            -TestId $TestId
    } catch {}
}

function TrustedUpdateWindow {
    if (-not (Test-Path $AllowFlag)) { return $false }
    $age = ((Get-Date).ToUniversalTime() - (Get-Item $AllowFlag).LastWriteTimeUtc).TotalMinutes
    return ($age -le 10)
}

while ($true) {
    try {
        $r = Invoke-FirewallBaselineDetection -FirewallRoot $FirewallRoot -BaselineMaxAgeDays 3

        if ($r.DriftDetected) {

            # ---- MALICIOUS WEAKENING ----
            if ($r.MaliciousDetected) {
                Notify "Critical" "Firewall compromise detected" `
                    ("Baseline drift with firewall weakening:`n" + ($r.MaliciousFindings -join "`n")) `
                    "Live-Baseline-Monitor"

                if (Test-Path $SelfHealScript) {
                    powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $SelfHealScript | Out-Null
                }

            # ---- BENIGN DRIFT (LEARNABLE) ----
            } else {
                if (TrustedUpdateWindow -and (Test-Path $AutoUpdateScript)) {
                    powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $AutoUpdateScript | Out-Null
                    Notify "Info" "Baseline updated" `
                        "Trusted update window detected. Baseline was refreshed." `
                        "Live-Baseline-Monitor"
                } else {
                    Notify "Warning" "Baseline drift detected" `
                        "No firewall weakening detected. Learning requires trusted update window." `
                        "Live-Baseline-Monitor"
                }
            }
        }
    } catch {}

    Start-Sleep -Seconds 60
}
