param(
  [Parameter(Mandatory=$false)]
  [string]$Root = (Get-Location).Path,

  [Parameter(Mandatory=$false)]
  [string]$OutFile = (Join-Path (Join-Path $env:ProgramData "FirewallCore\Logs") ("Gates_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")),

  [Parameter(Mandatory=$false)]
  [switch]$VerboseReport,

  # In DEV you often run gates with -ExecutionPolicy Bypass.
  # Keep this OFF by default, turn ON when validating release readiness.
  [Parameter(Mandatory=$false)]
  [switch]$EnforceSignatures
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Line {
  param([string]$s)
  $s | Out-File -FilePath $OutFile -Append -Encoding UTF8
  if ($VerboseReport) { Write-Host $s }
}

function Ensure-LogDir {
  $d = Split-Path -Parent $OutFile
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

function Gate-Parse {
  param([string]$File)
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$tokens, [ref]$errors)
  if ($errors -and $errors.Count -gt 0) {
    foreach ($e in $errors) {
      Write-Line ("PARSE_FAIL: {0} ({1}:{2}) {3}" -f $File, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber, $e.Message)
    }
    return $false
  }
  return $true
}

function Gate-PS51SyntaxScan {
  param([string]$File, [string]$Text)
  $bad = @()

  if ($Text -match "\?\?") { $bad += "PS7-only operator '??' detected" }
  if ($Text -match "ForEach-Object\s+-Parallel") { $bad += "PS7-only ForEach-Object -Parallel detected" }

  # This is a soft signal; still useful in this repo.
  if ($Text -match "\.Where\s*\(") { $bad += "Potential PS7-style .Where() usage detected" }

  if ($bad.Count -gt 0) {
    foreach ($b in $bad) { Write-Line ("PS51_RISK: {0} :: {1}" -f $File, $b) }
    return $false
  }
  return $true
}

function Gate-ScheduledTaskActionArgument {
  param([string]$File, [string]$Text)

  if ($Text -match "New-ScheduledTaskAction\b[\s\S]{0,300}-Argument\s+@\(.*\)") {
    Write-Line ("TASKARG_FAIL: {0} :: -Argument is an array (@(...)); must be a single string" -f $File)
    return $false
  }

  if ($Text -match "New-ScheduledTaskAction\b[\s\S]{0,300}-Argument\s+\(" -and $Text -match "New-ScheduledTaskAction\b[\s\S]{0,300}-Argument\s+\([^)]*,[^)]*\)") {
    Write-Line ("TASKARG_RISK: {0} :: -Argument may be multiple values; must be a single string" -f $File)
    return $false
  }

  return $true
}

function Gate-SignatureValid {
  param([string]$File)
  try {
    $sig = Get-AuthenticodeSignature -FilePath $File
    if ($sig.Status -ne 'Valid') {
      Write-Line ("SIG_FAIL: {0} :: {1} :: {2}" -f $File, $sig.Status, ($sig.StatusMessage -replace "\r?\n"," "))
      return $false
    }
    return $true
  } catch {
    Write-Line ("SIG_ERR: {0} :: {1}" -f $File, $_.Exception.Message)
    return $false
  }
}

Ensure-LogDir
Write-Line ("=== FirewallCore Gates === {0} Root={1}" -f (Get-Date -Format s), $Root)

# --- Deterministic scope (release surface only)
$includeRoots = @(
  (Join-Path $Root "Install-FirewallCore.ps1"),
  (Join-Path $Root "Uninstall-FirewallCore.ps1"),
  (Join-Path $Root "_internal"),
  (Join-Path $Root "Firewall\System"),
  (Join-Path $Root "Firewall\User"),
  (Join-Path $Root "Firewall\Modules")
)

$existing = @()
foreach ($p in $includeRoots) {
  if ([string]::IsNullOrWhiteSpace($p)) { continue }
  if (Test-Path -LiteralPath $p) { $existing += $p }
}
$includeRoots = $existing

$ps1 = @()
foreach ($p in $includeRoots) {
  $item = Get-Item -LiteralPath $p -ErrorAction Stop
  if ($item.PSIsContainer) {
    $ps1 += Get-ChildItem -LiteralPath $p -Recurse -File -Filter *.ps1 -ErrorAction Stop
  } else {
    $ps1 += $item
  }
}

# Final exclusions (belt + suspenders)
$ps1 = $ps1 | Where-Object {
  $full = $_.FullName
  ($full -notmatch "\\Tools\\") -and
  ($full -notmatch "\\Docs\\") -and
  ($full -notmatch "\\Firewall\\DEV-Only\\") -and
  ($full -notmatch "\\Firewall\\Monitor\\") -and
  ($full -notmatch "\\\.git\\") -and
  ($full -notmatch "\\FirewallInstaller\\")
}

$fail = $false

foreach ($f in $ps1) {
  $filePath = $f.FullName
  $text = [IO.File]::ReadAllText($filePath)

  if (-not (Gate-Parse -File $filePath)) { $fail = $true; continue }
  if (-not (Gate-PS51SyntaxScan -File $filePath -Text $text)) { $fail = $true }
  if (-not (Gate-ScheduledTaskActionArgument -File $filePath -Text $text)) { $fail = $true }

  if ($EnforceSignatures) {
    if (-not (Gate-SignatureValid -File $filePath)) { $fail = $true }
  }
}

if ($fail) {
  Write-Line "=== RESULT: FAIL (see findings above) ==="
  exit 2
} else {
  Write-Line "=== RESULT: PASS ==="
  exit 0
}

# SIG # Begin signature block
# MIIElAYJKoZIhvcNAQcCoIIEhTCCBIECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCdEBBpbgZwO3Pr
# bldmumLX2INUG0K/Az6ClICmLDbBXaCCArUwggKxMIIBmaADAgECAhQD4857cPuq
# YA1JZL+WI1Yn9crpsTANBgkqhkiG9w0BAQsFADAnMSUwIwYDVQQDDBxGaXJld2Fs
# bENvcmUgT2ZmbGluZSBSb290IENBMB4XDTI2MDIwMzA3NTU1N1oXDTI5MDMwOTA3
# NTU1N1owWDELMAkGA1UEBhMCVVMxETAPBgNVBAsMCFNlY3VyaXR5MRUwEwYDVQQK
# DAxGaXJld2FsbENvcmUxHzAdBgNVBAMMFkZpcmV3YWxsQ29yZSBTaWduYXR1cmUw
# WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATEFkC5IO0Ns0zPmdtnHpeiy/QjGyR5
# XcfYjx8wjVhMYoyZ5gyGaXjRBAnBsRsbSL172kF3dMSv20JufNI5SmZMo28wbTAJ
# BgNVHRMEAjAAMAsGA1UdDwQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNV
# HQ4EFgQUqbvNi/eHRRZJy7n5n3zuXu/sSOwwHwYDVR0jBBgwFoAULCjMhE2sOk26
# qY28GVmu4DqwehMwDQYJKoZIhvcNAQELBQADggEBAJsvjHGxkxvAWGAH1xiR+SOb
# vLKaaqVwKme3hHAXmTathgWUjjDwHQgFohPy7Zig2Msu11zlReUCGdGu2easaECF
# dMyiKzfZIA4+MQHQWv+SMcm912OjDtwEtCjNC0/+Q1BDISPv7OA8w7TDrmLk00mS
# il/f6Z4ZNlfegdoDyeDYK8lf+9DO2ARrddRU+wYrgXcdRzhekkBs9IoJ4qfXokOv
# u2ZvVZrPE3f2IiFPbmuBgzdbJ/VdkeCoAOl+D33Qyddzk8J/z7WSDiWqISF1E7GZ
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0x
# ggE1MIIBMQIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IKjg4pj8YbDSMTs+qRE9ruHYEQsgdI1bWiHWOKnp9SUTMAsGByqGSM49AgEFAARI
# MEYCIQDckyC8j6J3C8Ws1YNiqxN5QtAFApIEDnW4t5VoBqG0hwIhAJYGvo/ZPvLA
# LTxD4x3f7qqntykJhpm0AQYnDTldZ1XC
# SIG # End signature block
