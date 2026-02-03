# Invoke-FirewallNotifier.ps1
# Production listener for FirewallCore notifications (PS 5.1+ compatible)

[CmdletBinding()]
param(
    [int]$PollMs = 200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Ensure-Dir([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    if (!(Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }
}

function Get-PropValue($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    $p = $obj.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Normalize-Severity([string]$sev, [int]$eventId) {
    if ($sev) {
        $s = $sev.Trim().ToLowerInvariant()
        if ($s -in @("info","information")) { return "Info" }
        if ($s -in @("warn","warning")) { return "Warning" }
        if ($s -in @("crit","critical","error","fatal")) { return "Critical" }
    }
    # sane fallback if caller didn’t specify
    if ($eventId -ge 9000) { return "Critical" }
    if ($eventId -ge 4000) { return "Warning" }
    if ($eventId -ge 2000) { return "Warning" }
    return "Info"
}

function Default-SoundFor([string]$severity) {
    switch ($severity) {
        "Warning"  { return "chimes.wav" }
        "Critical" { return "chord.wav" }
        default    { return "ding.wav" }
    }
}

function Default-AutoCloseFor([string]$severity) {
    switch ($severity) {
        "Warning"  { return 30 }
        "Info"     { return 15 }
        default    { return 0 } # Critical = manual
    }
}

function Read-JsonSafe([string]$path) {
    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

function Read-EventViewMap([string]$path) {
    if (!(Test-Path -LiteralPath $path)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Get-MapEntry($mapObj, [string]$eventIdStr) {
    if ($null -eq $mapObj) { return $null }
    $p = $mapObj.PSObject.Properties[$eventIdStr]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Play-Wav([string]$wavName) {
    if ([string]::IsNullOrWhiteSpace($wavName)) { return }
    $wavPath = $wavName
    if (!(Test-Path -LiteralPath $wavPath)) {
        $candidate = Join-Path $env:WINDIR ("Media\" + $wavName)
        if (Test-Path -LiteralPath $candidate) { $wavPath = $candidate }
    }
    if (!(Test-Path -LiteralPath $wavPath)) { return }

    try {
        $sp = New-Object System.Media.SoundPlayer $wavPath
        $sp.Play()
    } catch { }
}

function Export-FilteredEvtx([string]$logName, [int]$eventId, [string]$outDir) {
    Ensure-Dir $outDir
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
    $out = Join-Path $outDir ("{0}_EID{1}_{2}.evtx" -f $logName, $eventId, $stamp)
    $query = "*[System[(EventID=$eventId)]]"
    try {
        & wevtutil.exe epl $logName $out "/q:$query" "/ow:true" 2>$null | Out-Null
        if (Test-Path -LiteralPath $out) { return $out }
    } catch { }
    return $null
}

function Open-EventViewerFor([string]$logName, [int]$eventId, [string]$tempDir) {
    if ([string]::IsNullOrWhiteSpace($logName)) { $logName = "FirewallCore" }
    $evtx = Export-FilteredEvtx -logName $logName -eventId $eventId -outDir $tempDir
    if ($evtx) {
        Start-Process -FilePath "eventvwr.msc" -ArgumentList ("/l:`"{0}`"" -f $evtx) | Out-Null
        return
    }
    # fallback: open Event Viewer normally
    Start-Process -FilePath "eventvwr.msc" | Out-Null
}

function Show-Dialog(
    [string]$severity,
    [string]$title,
    [string]$message,
    [int]$eventId,
    [string]$logName,
    [string]$soundName,
    [int]$autoCloseSec,
    [bool]$requireAck,
    [bool]$center
) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Width = 560
    $form.Height = 240
    $form.TopMost = $true
    $form.StartPosition = if ($center) { "CenterScreen" } else { "Manual" }
    $form.BackColor = [System.Drawing.Color]::White

    if ($requireAck) {
        # No X button for critical
        $form.ControlBox = $false
        $form.FormBorderStyle = "FixedDialog"
    } else {
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
    }

    if (-not $center) {
        $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $form.Left = $wa.Right - $form.Width - 18
        $form.Top  = $wa.Bottom - $form.Height - 18
    }

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Left = 16
    $lblTitle.Top = 14
    $lblTitle.Width = 520
    $lblTitle.Height = 28
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Text = $title
    $form.Controls.Add($lblTitle)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Left = 16
    $tb.Top = 48
    $tb.Width = 520
    $tb.Height = 110
    $tb.Multiline = $true
    $tb.ReadOnly = $true
    $tb.ScrollBars = "Vertical"
    $tb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $tb.Text = $message
    $form.Controls.Add($tb)

    $btnReview = New-Object System.Windows.Forms.Button
    $btnReview.Text = "Review logs"
    $btnReview.Width = 110
    $btnReview.Height = 28
    $btnReview.Left = 16
    $btnReview.Top = 168
    $form.Controls.Add($btnReview)

    $btnClose = $null
    $btnAck   = $null

    if ($requireAck) {
        $btnAck = New-Object System.Windows.Forms.Button
        $btnAck.Text = "I acknowledge"
        $btnAck.Width = 130
        $btnAck.Height = 28
        $btnAck.Left = 406
        $btnAck.Top = 168
        $form.Controls.Add($btnAck)
    } else {
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Text = "Close"
        $btnClose.Width = 90
        $btnClose.Height = 28
        $btnClose.Left = 446
        $btnClose.Top = 168
        $form.Controls.Add($btnClose)
        $form.AcceptButton = $btnClose
    }

    $tempDir = Join-Path $env:ProgramData "FirewallCore\NotifyQueue\Temp"
    Ensure-Dir $tempDir

    $btnReview.Add_Click({
        Open-EventViewerFor -logName $logName -eventId $eventId -tempDir $tempDir
        if (-not $requireAck) {
            try { $form.Close() } catch { }
        }
    })

    if ($btnClose) {
        $btnClose.Add_Click({
            try { $form.Close() } catch { }
        })
    }

    if ($btnAck) {
        $btnAck.Add_Click({
            try { $form.Close() } catch { }
        })
    }

    # Sound once on show
    $form.Add_Shown({ Play-Wav $soundName })

    # Auto close timer (Info/Warn)
    $timerClose = $null
    if ($autoCloseSec -gt 0 -and -not $requireAck) {
        $remaining = $autoCloseSec
        $timerClose = New-Object System.Windows.Forms.Timer
        $timerClose.Interval = 1000
        $timerClose.Add_Tick({
            $remaining--
            if ($remaining -le 0) {
                $timerClose.Stop()
                try { $form.Close() } catch { }
            }
        })
        $timerClose.Start()
        $form.Add_FormClosed({ try { $timerClose.Stop(); $timerClose.Dispose() } catch { } })
    }

    # Critical repeat sound until ack
    $timerRepeat = $null
    if ($requireAck) {
        $timerRepeat = New-Object System.Windows.Forms.Timer
        $timerRepeat.Interval = 8000
        $timerRepeat.Add_Tick({ Play-Wav $soundName })
        $timerRepeat.Start()
        $form.Add_FormClosed({ try { $timerRepeat.Stop(); $timerRepeat.Dispose() } catch { } })
    }

    [void]$form.ShowDialog()
}

function Process-OneFile([string]$filePath, $eventViewMap) {
    $data = Read-JsonSafe $filePath
    if ($null -eq $data) { throw "Empty/invalid JSON." }

    $eventId = [int](Get-PropValue $data "EventId")
    $sevRaw  = [string](Get-PropValue $data "Severity")
    $title   = [string](Get-PropValue $data "Title")
    $msg     = [string](Get-PropValue $data "Message")

    if ([string]::IsNullOrWhiteSpace($title)) { $title = "FirewallCore Alert" }
    if ([string]::IsNullOrWhiteSpace($msg))   { $msg = "(no message provided)" }

    $eventIdStr = [string]$eventId
    $mapEntry = Get-MapEntry $eventViewMap $eventIdStr

    $logName = [string](Get-PropValue $mapEntry "Log")
    if ([string]::IsNullOrWhiteSpace($logName)) { $logName = "FirewallCore" }

    $severity = Normalize-Severity -sev $sevRaw -eventId $eventId

    # Sound: message overrides map overrides defaults
    $sound = [string](Get-PropValue $data "Sound")
    if ([string]::IsNullOrWhiteSpace($sound)) {
        $sound = [string](Get-PropValue $mapEntry "Sound")
    }
    if ([string]::IsNullOrWhiteSpace($sound)) {
        $sound = Default-SoundFor $severity
    }

    # AutoClose: message overrides map overrides defaults
    $ac = 0
    $acRaw = Get-PropValue $data "AutoCloseSec"
    if ($acRaw -ne $null) { $ac = [int]$acRaw }
    if ($ac -le 0) {
        $mapAc = Get-PropValue $mapEntry "AutoCloseSec"
        if ($mapAc -ne $null) { $ac = [int]$mapAc }
    }
    if ($ac -le 0) { $ac = Default-AutoCloseFor $severity }

    $center = ($severity -ne "Info")  # Warn/Critical centered
    $requireAck = ($severity -eq "Critical")

    if ($severity -eq "Critical") {
        # Force deterministic critical wording
        $msg = $msg + "`r`n`r`nMANUAL REVIEW REQUIRED:`r`n1) Click 'Review logs'`r`n2) Confirm the event details`r`n3) Click 'I acknowledge' to dismiss"
    }

    Show-Dialog -severity $severity -title $title -message $msg -eventId $eventId -logName $logName -soundName $sound -autoCloseSec $ac -requireAck:$requireAck -center:$center
}

# ---------------- MAIN LOOP ----------------
$queueRoot  = Join-Path $env:ProgramData "FirewallCore\NotifyQueue"
$pendingDir = Join-Path $queueRoot "Pending"
$procDir    = Join-Path $queueRoot "Processed"
$failDir    = Join-Path $queueRoot "Failed"
Ensure-Dir $pendingDir
Ensure-Dir $procDir
Ensure-Dir $failDir

$mapPath = Join-Path $env:ProgramData "FirewallCore\EventViewMap.json"

Write-Host "[FirewallCore] Dialog notifier running (no tray / no balloons)" -ForegroundColor Cyan
while ($true) {
    try { [System.Windows.Forms.Application]::DoEvents() | Out-Null } catch { }

    $eventViewMap = Read-EventViewMap $mapPath

    $files = Get-ChildItem -LiteralPath $pendingDir -Filter "*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime

    foreach ($f in $files) {
        $src = $f.FullName
        $work = Join-Path $queueRoot ("Processing\" + $f.Name)
        Ensure-Dir (Split-Path -Parent $work)

        try {
            Move-Item -LiteralPath $src -Destination $work -Force

            Process-OneFile -filePath $work -eventViewMap $eventViewMap

            $done = Join-Path $procDir ($f.BaseName + "_" + ([guid]::NewGuid().ToString("N")) + ".json")
            Move-Item -LiteralPath $work -Destination $done -Force
        } catch {
            $err = $_.Exception.Message
            Write-Host ("[WARN] Failed: {0} -> {1}" -f $f.Name, $err) -ForegroundColor Yellow
            try {
                $dstFail = Join-Path $failDir ($f.BaseName + "_" + ([guid]::NewGuid().ToString("N")) + ".json")
                if (Test-Path -LiteralPath $work) {
                    Move-Item -LiteralPath $work -Destination $dstFail -Force
                } elseif (Test-Path -LiteralPath $src) {
                    Move-Item -LiteralPath $src -Destination $dstFail -Force
                }
            } catch { }
        }
    }

    Start-Sleep -Milliseconds $PollMs
}

# SIG # Begin signature block
# MIIEbgYJKoZIhvcNAQcCoIIEXzCCBFsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGxKgWR4kXUGnPCaKezJex73t
# InagggK1MIICsTCCAZmgAwIBAgIUA+POe3D7qmANSWS/liNWJ/XK6bEwDQYJKoZI
# hvcNAQELBQAwJzElMCMGA1UEAwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBD
# QTAeFw0yNjAyMDMwNzU1NTdaFw0yOTAzMDkwNzU1NTdaMFgxCzAJBgNVBAYTAlVT
# MREwDwYDVQQLDAhTZWN1cml0eTEVMBMGA1UECgwMRmlyZXdhbGxDb3JlMR8wHQYD
# VQQDDBZGaXJld2FsbENvcmUgU2lnbmF0dXJlMFkwEwYHKoZIzj0CAQYIKoZIzj0D
# AQcDQgAExBZAuSDtDbNMz5nbZx6Xosv0IxskeV3H2I8fMI1YTGKMmeYMhml40QQJ
# wbEbG0i9e9pBd3TEr9tCbnzSOUpmTKNvMG0wCQYDVR0TBAIwADALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKm7zYv3h0UWScu5+Z98
# 7l7v7EjsMB8GA1UdIwQYMBaAFCwozIRNrDpNuqmNvBlZruA6sHoTMA0GCSqGSIb3
# DQEBCwUAA4IBAQCbL4xxsZMbwFhgB9cYkfkjm7yymmqlcCpnt4RwF5k2rYYFlI4w
# 8B0IBaIT8u2YoNjLLtdc5UXlAhnRrtnmrGhAhXTMois32SAOPjEB0Fr/kjHJvddj
# ow7cBLQozQtP/kNQQyEj7+zgPMO0w65i5NNJkopf3+meGTZX3oHaA8ng2CvJX/vQ
# ztgEa3XUVPsGK4F3HUc4XpJAbPSKCeKn16JDr7tmb1WazxN39iIhT25rgYM3Wyf1
# XZHgqADpfg990MnXc5PCf8+1kg4lqiEhdROxmSko4EKfHPTHE3FteWJuDEfpW8p9
# /gooBjq5fPZc4TMppuq4+r0m70jJpdgBEIB9MYIBIzCCAR8CAQEwPzAnMSUwIwYD
# VQQDDBxGaXJld2FsbENvcmUgT2ZmbGluZSBSb290IENBAhQD4857cPuqYA1JZL+W
# I1Yn9crpsTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU2zORnxYSYbYeTuwsDc6Copo5LrMwCwYH
# KoZIzj0CAQUABEcwRQIgObv1Qdsccit5OjjRZmTnwuGN0Fsj3DOyvyeXZ5aOfngC
# IQDkj9rYxY1l/dDJgy1iVMsbZLUZRkv0NXfGo4EWpig90Q==
# SIG # End signature block
