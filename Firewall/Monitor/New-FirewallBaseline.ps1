[CmdletBinding()]
param(
    [string]$FirewallRoot = "C:\FirewallInstaller\Firewall",

    # Files you want to lock for v1 baseline:
    [string[]]$Targets = @(
        "C:\FirewallInstaller\Firewall\Policy\Default-Inbound.txt",
        "C:\FirewallInstaller\Firewall\Policy\Default-Outbound.txt",
        "C:\FirewallInstaller\Firewall\Policy\Default-Policy.wfw"
    ),

    [ValidateSet("SHA256","SHA512")]
    [string]$Algorithm = "SHA256",

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log($m){ if(-not $Quiet){ Write-Host $m } }

$StateDir    = Join-Path $FirewallRoot "State\Baseline"
$JsonOutPath = Join-Path $StateDir "baseline.sha256.json"
$TxtOutPath  = Join-Path $StateDir "baseline.sha256.txt"
New-Item $StateDir -ItemType Directory -Force | Out-Null

$items = @()

foreach ($p in $Targets) {
    if (-not (Test-Path $p)) {
        throw "Baseline target missing: $p"
    }

    $fi = Get-Item $p
    $hash = (Get-FileHash -Algorithm $Algorithm -Path $p).Hash

    $items += [pscustomobject]@{
        Path          = $fi.FullName
        Sha256        = $hash   # keep field name stable for v1 schema
        Length        = [int64]$fi.Length
        LastWriteTime = $fi.LastWriteTimeUtc.ToString("o")
    }
}

$baseline = [pscustomobject]@{
    SchemaVersion = 1
    Algorithm     = $Algorithm
    CreatedUtc    = (Get-Date).ToUniversalTime().ToString("o")
    FirewallRoot  = $FirewallRoot
    Items         = $items
}

$baseline | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonOutPath -Encoding UTF8

# Also emit a simple checksums txt (handy for humans / CI)
$txt = $items | ForEach-Object { "{0}  {1}" -f $_.Sha256, $_.Path }
$txt | Set-Content -Path $TxtOutPath -Encoding ASCII

Log "[OK] Baseline written:"
Log "     $JsonOutPath"
Log "     $TxtOutPath"
