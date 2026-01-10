# =========================
# FirewallCore Notifier - FULL CONSOLE OVERRIDE (Option A)
# Fixes:
#  - No tray/balloons
#  - Info/Warn/Critical WAV-only (NO SystemSounds)
#  - Info/Warn auto-close + X closes cleanly (no timer runtime crash)
#  - Click anywhere on toast opens Event Viewer (best-effort) + closes toast
#  - Exactly-once queue consumption (atomic move Pending -> Processing -> Processed/Failed)
# =========================

$Path = "C:\Firewall\Monitor\Invoke-FirewallNotifier.ps1"
$Backup = "$Path.bak_{0:yyyyMMdd_HHmmss}" -f (Get-Date)

# 0) Kill any running consumers
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like "*Invoke-FirewallNotifier.ps1*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# 1) Backup current file
Copy-Item -LiteralPath $Path -Destination $Backup -Force
Write-Host "[OK] Backed up to: $Backup" -ForegroundColor Green

# 2) Overwrite with known-good script
@'
# Invoke-FirewallNotifier.ps1
# FirewallCore JSON queue consumer + WinForms toast dialogs (WAV-only)

# --- Config ---
$script:QueueRoot  = Join-Path $env:ProgramData "FirewallCore\NotifyQueue"
$script:Pending    = Join-Path $script:QueueRoot "Pending"
$script:Processing = Join-Path $script:QueueRoot "Processing"
$script:Processed  = Join-Path $script:QueueRoot "Processed"
$script:Failed     = Join-Path $script:QueueRoot "Failed"

$script:MediaDir   = Join-Path $env:WINDIR "Media"
$script:SoundInfo  = Join-Path $script:MediaDir "ding.wav"     # per your requirement
$script:SoundWarn  = Join-Path $script:MediaDir "chimes.wav"
$script:SoundCrit  = Join-Path $script:MediaDir "chord.wav"

$script:InfoAutoCloseSec = 8
$script:WarnAutoCloseSec = 12
$script:Trace = $false

# --- UI assemblies ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Write-Trace([string]$Msg, [string]$Color = "DarkGray") {
    if (-not $script:Trace) { return }
    try { Write-Host $Msg -ForegroundColor $Color } catch {}
}

function Ensure-Dirs {
    foreach ($d in @($script:QueueRoot,$script:Pending,$script:Processing,$script:Processed,$script:Failed)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
    }
}

function Get-UniquePath([string]$Dir, [string]$FileName) {
    $base = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext  = [IO.Path]::GetExtension($FileName)
    $dest = Join-Path $Dir $FileName
    if (-not (Test-Path $dest)) { return $dest }
    $dest = Join-Path $Dir ("{0}_{1}{2}" -f $base, ([guid]::NewGuid().ToString("N")), $ext)
    return $dest
}

function Open-EventViewerBestEffort {
    # We try a couple of common entrypoints; if args aren't supported, fall back to plain open.
    try {
        Start-Process -FilePath "$env:WINDIR\System32\eventvwr.exe" -ArgumentList "/l:FirewallCore" -ErrorAction Stop | Out-Null
        return
    } catch {}
    try {
        Start-Process -FilePath "$env:WINDIR\System32\eventvwr.exe" -ArgumentList "/c:FirewallCore" -ErrorAction Stop | Out-Null
        return
    } catch {}
    try {
        Start-Process -FilePath "$env:WINDIR\System32\eventvwr.msc" -ErrorAction Stop | Out-Null
        return
    } catch {}
    try { Start-Process "eventvwr.msc" | Out-Null } catch {}
}

function Play-WavOnly([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    try {
        $sp = New-Object System.Media.SoundPlayer $Path
        $sp.Load()
        $sp.Play()  # async (non-blocking)
    } catch {
        Write-Trace ("[TRACE] WAV play failed: {0}" -f $_.Exception.Message) "DarkYellow"
    }
}

function Show-FirewallToast {
    param(
        [Parameter(Mandatory)][string]$Severity,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )

    # Pick WAV (NO SystemSounds)
    switch ($Severity.ToLowerInvariant()) {
        "info"     { Play-WavOnly $script:SoundInfo }
        "warning"  { Play-WavOnly $script:SoundWarn }
        "warn"     { Play-WavOnly $script:SoundWarn }
        "critical" { Play-WavOnly $script:SoundCrit }
        default    { Play-WavOnly $script:SoundInfo }
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.StartPosition = 'Manual'
    $form.Size = New-Object System.Drawing.Size(420,170)

    # Position bottom-right of primary working area (safe; no op_Subtraction)
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x = [Math]::Max($wa.Left,  $wa.Right  - $form.Width  - 12)
    $y = [Math]::Max($wa.Top,   $wa.Bottom - $form.Height - 12)
    $form.Location = New-Object System.Drawing.Point($x,$y)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.AutoSize = $false
    $lblTitle.Location = New-Object System.Drawing.Point(12,12)
    $lblTitle.Size = New-Object System.Drawing.Size(390,22)
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Text = $Title

    $lblMsg = New-Object System.Windows.Forms.Label
    $lblMsg.AutoSize = $false
    $lblMsg.Location = New-Object System.Drawing.Point(12,42)
    $lblMsg.Size = New-Object System.Drawing.Size(390,70)
    $lblMsg.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblMsg.Text = $Message

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.Size = New-Object System.Drawing.Size(80,26)
    $btnClose.Location = New-Object System.Drawing.Point(322,118)

    $form.Controls.Add($lblTitle)
    $form.Controls.Add($lblMsg)
    $form.Controls.Add($btnClose)

    # Clean timer lifecycle (prevents .NET runtime crashes when closing)
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $script:deadline = $null

    $autoClose = 0
    if ($Severity.ToLowerInvariant() -in @("info")) { $autoClose = $script:InfoAutoCloseSec }
    elseif ($Severity.ToLowerInvariant() -in @("warn","warning")) { $autoClose = $script:WarnAutoCloseSec }
    elseif ($Severity.ToLowerInvariant() -eq "critical") { $autoClose = 0 } # critical stays until user closes

    if ($autoClose -gt 0) {
        $script:deadline = (Get-Date).AddSeconds($autoClose)
        $timer.Add_Tick({
            try {
                if ($script:deadline -and (Get-Date) -ge $script:deadline) {
                    $timer.Stop()
                    $form.Close()
                }
            } catch {}
        })
    }

    $form.Add_FormClosing({
        try { $timer.Stop() } catch {}
        try { $timer.Dispose() } catch {}
    })

    $btnClose.Add_Click({ $form.Close() })

    # Click anywhere (form/title/message) opens Event Viewer + closes toast
    $openAndClose = {
        try { Open-EventViewerBestEffort } catch {}
        try { $form.Close() } catch {}
    }
    $form.Add_Click($openAndClose)
    $lblTitle.Add_Click($openAndClose)
    $lblMsg.Add_Click($openAndClose)

    # Show non-modal so consumer keeps running; DoEvents() in main loop drives UI/timers
    $form.Add_Shown({ if ($autoClose -gt 0) { try { $timer.Start() } catch {} } })
    $null = $form.Show()
}

function Parse-NotifyJson([string]$JsonPath) {
    $raw = Get-Content -LiteralPath $JsonPath -Raw -ErrorAction Stop
    return ($raw | ConvertFrom-Json -ErrorAction Stop)
}

function Process-One([string]$PendingFile) {
    $name = [IO.Path]::GetFileName($PendingFile)

    # Atomic move to Processing (exactly-once)
    $processingPath = Get-UniquePath $script:Processing $name
    try {
        Move-Item -LiteralPath $PendingFile -Destination $processingPath -Force -ErrorAction Stop
    } catch {
        Write-Trace "[TRACE] Move to Processing failed ($name): $($_.Exception.Message)" "DarkYellow"
        return
    }

    try {
        $n = Parse-NotifyJson $processingPath

        $sev = [string]$n.Severity
        if ([string]::IsNullOrWhiteSpace($sev)) { $sev = "Info" }

        $title = [string]$n.Title
        if ([string]::IsNullOrWhiteSpace($title)) { $title = "FirewallCore" }

        $msg = [string]$n.Message
        if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "" }

        Show-FirewallToast -Severity $sev -Title $title -Message $msg

        # Move to Processed after dispatch
        $processedPath = Get-UniquePath $script:Processed $name
        Move-Item -LiteralPath $processingPath -Destination $processedPath -Force -ErrorAction Stop
    }
    catch {
        $failedPath = Get-UniquePath $script:Failed $name
        try { Move-Item -LiteralPath $processingPath -Destination $failedPath -Force -ErrorAction Stop } catch {}
        Write-Trace ("[TRACE] Failed processing {0}: {1}" -f $name, $_.Exception.Message) "Red"
    }
}

# --- Main ---
Ensure-Dirs
Write-Host "[FirewallCore] Dialog notifier running (NO tray / NO balloons)" -ForegroundColor Cyan

while ($true) {
    try {
        # Drive WinForms events/timers (this is our message pump)
        [System.Windows.Forms.Application]::DoEvents() | Out-Null

        $files = @(Get-ChildItem -LiteralPath $script:Pending -Filter *.json -File -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime)

        foreach ($f in $files) {
            Process-One -PendingFile $f.FullName
        }
    } catch {
        Write-Trace ("[TRACE] Loop error: {0}" -f $_.Exception.Message) "DarkYellow"
    }

    Start-Sleep -Milliseconds 200
}
'@ | Set-Content -LiteralPath $Path -Encoding UTF8 -Force

Write-Host "[OK] Overrode Invoke-FirewallNotifier.ps1 (full reset)" -ForegroundColor Green

# 3) (Optional) Clear test noise so INFO validation is clean
Remove-Item "$env:ProgramData\FirewallCore\NotifyQueue\Pending\*.json"    -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\FirewallCore\NotifyQueue\Processing\*.json" -Force -ErrorAction SilentlyContinue

Write-Host "[OK] Cleared Pending/Processing (Processed/Failed preserved)" -ForegroundColor Green

# 4) Start consumer in foreground for validation
powershell -STA -NoProfile -ExecutionPolicy Bypass -File $Path
