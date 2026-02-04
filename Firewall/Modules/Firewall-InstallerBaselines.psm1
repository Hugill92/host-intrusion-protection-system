Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$path = "C:\FirewallInstaller\Firewall\Modules\Firewall-InstallerBaselines.psm1"
if (-not (Test-Path -LiteralPath $path)) { throw "Missing file: $path" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item -LiteralPath $path -Destination ($path + ".bak_" + $ts) -Force

$src = Get-Content -LiteralPath $path -Raw

$fixedFunc = @'
function Resolve-FirewallCoreProgramDataRoot {
  [CmdletBinding()]
  param()

  # StrictMode-safe: never touch script-scope ProgramDataRoot variable unless it exists
  $sv = Get-Variable -Name ProgramDataRoot -Scope Script -ErrorAction SilentlyContinue
  if ($sv -and -not [string]::IsNullOrWhiteSpace([string]$sv.Value)) {
    return [string]$sv.Value
  }

  $gv = Get-Variable -Name ProgramDataRoot -Scope Global -ErrorAction SilentlyContinue
  if ($gv -and -not [string]::IsNullOrWhiteSpace([string]$gv.Value)) {
    return [string]$gv.Value
  }

  return (Join-Path $env:ProgramData 'FirewallCore')
}
'@

# Replace existing Resolve-FirewallCoreProgramDataRoot definition (entire function block)
$pattern = "(?ms)function\s+Resolve-FirewallCoreProgramDataRoot\s*\{.*?\r?\n\}"
$patched = [regex]::Replace($src, $pattern, $fixedFunc, 1)

if ($patched -eq $src) {
}

Set-Content -LiteralPath $path -Value $patched -Encoding UTF8

# Parse gate (must be 0 errors)
$tok = $null; $err = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tok, [ref]$err)
if ($err.Count -gt 0) {
  Write-Host "[PARSE FAIL] $path" -ForegroundColor Red
  $err | ForEach-Object {
    $_.Message
    $_.Extent | Format-List StartLineNumber,StartColumnNumber,EndLineNumber,EndColumnNumber,Text
  }
  throw "Parse failed; see details above."
}

Write-Host "[FIX OK] Resolve-FirewallCoreProgramDataRoot is now StrictMode-safe." -ForegroundColor Green
Write-Host "Reminder: re-sign this module before AllSigned testing." -ForegroundColor Yellow


function Get-FirewallCoreSha256Hex {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$LiteralPath)

  if (Get-Command -Name Get-FileHash -ErrorAction SilentlyContinue) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $LiteralPath).Hash.ToLowerInvariant()
  }

  # Fallback: pure .NET (PS3+ safe)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $fs = [System.IO.File]::OpenRead($LiteralPath)
    try { $hashBytes = $sha.ComputeHash($fs) } finally { $fs.Dispose() }
  } finally { $sha.Dispose() }

  return ([BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
}
function Import-InstallerBaselineModule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$InstallerRoot
  )

  $mod = Join-Path $InstallerRoot 'Tools\Modules\FirewallBaseline.psm1'
  if (-not (Test-Path -LiteralPath $mod)) {
    throw "Missing required baseline module: $mod"
  }

  Import-Module -Name $mod -Force -ErrorAction Stop
}

function Resolve-FirewallCoreProgramDataRoot {
  [CmdletBinding()]
  param()

  # StrictMode-safe: never touch script-scope ProgramDataRoot variable unless it exists
  $sv = Get-Variable -Name ProgramDataRoot -Scope Script -ErrorAction SilentlyContinue
  if ($sv -and -not [string]::IsNullOrWhiteSpace([string]$sv.Value)) {
    return [string]$sv.Value
  }

  $gv = Get-Variable -Name ProgramDataRoot -Scope Global -ErrorAction SilentlyContinue
  if ($gv -and -not [string]::IsNullOrWhiteSpace([string]$gv.Value)) {
    return [string]$gv.Value
  }

  return (Join-Path $env:ProgramData 'FirewallCore')
}



function Resolve-FirewallCorePolicySource {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$InstallerRoot
  )

  $candidates = @(
    (Join-Path $InstallerRoot 'Firewall\Policy\FirewallCorePolicy.wfw'),
    (Join-Path $InstallerRoot 'FirewallCorePolicy.wfw')
  ) | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -Unique

  foreach ($c in $candidates) {
    try {
      $p = Resolve-Path -LiteralPath $c -ErrorAction SilentlyContinue
      if ($p) { return $p.Path }
    } catch {}
  }

  throw "Missing FirewallCore policy file. Expected one of: $($candidates -join ', ')"
}

function Export-NetshFirewallBaselineBundle {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$BaselineRoot,

    [Parameter(Mandatory)]
    [ValidateSet('PRE_INSTALL','POST_INSTALL')]
    [string]$Type,

    [Parameter(Mandatory)]
    [string]$Stamp,

    [string]$FileBaseName = $null,

    [string]$Mode = ''
  )

  if (-not $FileBaseName) {
    $FileBaseName = if ($Type -eq 'PRE_INSTALL') { 'Firewall_PRE.wfw' } else { 'Firewall_POST.wfw' }
  }

  New-Item -ItemType Directory -Path $BaselineRoot -Force | Out-Null

  $dir = Join-Path $BaselineRoot ("{0}_{1}" -f $Type, $Stamp)
  New-Item -ItemType Directory -Path $dir -Force | Out-Null

  $wfw = Join-Path $dir $FileBaseName
  & netsh.exe advfirewall export $wfw | Out-Null

  # Legacy (backward-compatible) hash evidence
  $legacySha = $wfw + '.sha256'
  $h = Get-FirewallCoreSha256Hex -LiteralPath $wfw
("{0} *{1}" -f $h, (Split-Path -Leaf $wfw)) |
    Out-File -LiteralPath $legacySha -Encoding ascii


  $manifestPath = $null
  $sumsPath = $null
  $verifyOk = $false

  try {
    $relFiles = @(
      (Split-Path -Leaf $wfw),
      (Split-Path -Leaf $legacySha)
    )

    $sumsPath = Write-FwBaselineSha256Sums -Root $dir -Files $relFiles -OutFile (Join-Path $dir 'SHA256SUMS.txt')
    $manifestPath = Write-FwBaselineManifest -Root $dir -Files $relFiles -Meta @{
      BundleId     = $Stamp
      Type         = $Type
      Mode         = $Mode
      ComputerName = $env:COMPUTERNAME
      UserName     = $env:USERNAME
      BuiltAtUtc   = (Get-Date).ToUniversalTime().ToString('o')
    } -OutFile (Join-Path $dir 'BaselineManifest.json')

    $v = Test-FwBaselineManifest -ManifestPath $manifestPath
    $verifyOk = [bool]$v.Valid
  } catch {
    # Best-effort: legacy artifacts remain authoritative if manifest generation fails.
    $verifyOk = $false
  }

  return [pscustomobject]@{
    Type         = $Type
    Stamp        = $Stamp
    Dir          = $dir
    WfwPath      = $wfw
    LegacySha256 = $legacySha
    Sha256Sums   = $sumsPath
    Manifest     = $manifestPath
    ManifestOk   = $verifyOk
  }
}

function Invoke-FirewallCorePolicyApplyWithBaselines {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$InstallerRoot,

    [string]$ProgramDataRoot,

    [Parameter(Mandatory)]
    [string]$Stamp,

    [string]$Mode = ''
  )

  # Resolve ProgramData root deterministically if caller did not provide it
  if (-not $PSBoundParameters.ContainsKey('ProgramDataRoot') -or [string]::IsNullOrWhiteSpace($ProgramDataRoot)) {
    $ProgramDataRoot = Resolve-FirewallCoreProgramDataRoot
  }

  Import-InstallerBaselineModule -InstallerRoot $InstallerRoot

  $policySrc = Resolve-FirewallCorePolicySource -InstallerRoot $InstallerRoot

  $policyDir = Join-Path $ProgramDataRoot 'Policy'
  $policyDst = Join-Path $policyDir 'FirewallCorePolicy.wfw'
  $baselineRoot = Join-Path $ProgramDataRoot 'Baselines'

  New-Item -ItemType Directory -Path $policyDir -Force | Out-Null
  New-Item -ItemType Directory -Path $baselineRoot -Force | Out-Null

  Copy-Item -LiteralPath $policySrc -Destination $policyDst -Force

  # Safety gate: refuse tiny/empty policy
  if ((Get-Item -LiteralPath $policyDst).Length -lt 10240) {
    throw "Policy file too small - refusing to apply. Path: $policyDst"
  }

  $pre = Export-NetshFirewallBaselineBundle -BaselineRoot $baselineRoot -Type PRE_INSTALL -Stamp $Stamp -Mode $Mode

  & netsh.exe advfirewall import $policyDst | Out-Null

  $post = Export-NetshFirewallBaselineBundle -BaselineRoot $baselineRoot -Type POST_INSTALL -Stamp $Stamp -Mode $Mode

  return [pscustomobject]@{
    PolicySrc    = $policySrc
    PolicyDst    = $policyDst
    BaselineRoot = $baselineRoot
    Pre          = $pre
    Post         = $post
  }
}


Export-ModuleMember -Function Invoke-FirewallCorePolicyApplyWithBaselines

# SIG # Begin signature block
# MIIa9gYJKoZIhvcNAQcCoIIa5zCCGuMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAynLn0Jfo5cKwI
# J+52ugd9/qgO5D0YgSqQWVhfJQpJzaCCFe8wggKxMIIBmaADAgECAhQD4857cPuq
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
# KSjgQp8c9McTcW15Ym4MR+lbyn3+CigGOrl89lzhMymm6rj6vSbvSMml2AEQgH0w
# ggWNMIIEdaADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskh
# PfKK2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIP
# Uh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvu
# INXJIB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59U
# WI4MK7dPpzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4
# AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJoz
# QL8I11pJpMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw
# 4KISG2aadMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sE
# AMx9HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZD
# pBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsx
# xcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+Y
# HS312amyHeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
# BBTs1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYun
# pyGd823IDzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUF
# BzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6
# Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5j
# cnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJ
# KoZIhvcNAQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqka
# uyL4hxppVCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP
# +fT3rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8Lpuny
# NDzs9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiE
# n2/K2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4
# VC0nftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwgga0MIIEnKADAgECAhAN
# x6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# ITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAw
# MDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3Rh
# bXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMs
# VO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4
# kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8
# BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2
# Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwF
# t+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9o
# HRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq
# 6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+r
# x3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvU
# BDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl
# 9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwID
# AQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunk
# Bnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08w
# DgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEB
# BGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsG
# AQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4H
# PRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qE
# JPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy
# 9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe
# 9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1U
# H410ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6
# A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjs
# Yg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0
# vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/D
# Jbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHb
# xtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAP
# vIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIG7TCCBNWgAwIBAgIQCoDvGEuN8QWC
# 0cR2p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMO
# RGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGlt
# ZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAwMDAw
# MFoXDTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1l
# c3RhbXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx+wvA
# 69HFTBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvNZh6w
# W2R6kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlLnh00
# Cll8pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmncOOM
# A3CoB/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjPKHW5KqCvpSduSwhwUmot
# uQhcg9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL4Q1O
# pbybpMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7wJNdoRORVbPR1VVnDuSeH
# VZlc4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCyFG1r
# oSrgHjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOgrY7rlRyTlaCCfw7aSURO
# wnu7zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K096V1hE0yZIXe+giAwW0
# 0aHzrDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGjggGV
# MIIBkTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zyMe39/dfzkXFjGVBDz2GM
# 6DAfBgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMC
# B4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQG
# CCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKG
# UWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRp
# bWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSg
# UqBQhk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRU
# aW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAI
# BgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3xHCcE
# ua5gQezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh8/Ym
# RDfxT7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/ML9lFfim8/9yJmZSe2F8
# AQ/UdKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu+WUqW4daIqToXFE/JQ/E
# ABgfZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4obEMnxYOX8VBRKe1uNnzQ
# VTeLni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq8/gV
# utDojBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasnM9AWcIQfVjnzrvwiCZ85
# EE8LUkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol/DJgddJ35XTxfUlQ+8Hg
# gt8l2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1R9xJ
# gKf47CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3ocCVccAvlKV9jEnstrniLv
# UxxVZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcBZU8atufk+EMF/cWuiC7P
# OGT75qaL6vdCvHlshtjdNXOCIUjsarfNZzGCBF0wggRZAgEBMD8wJzElMCMGA1UE
# AwwcRmlyZXdhbGxDb3JlIE9mZmxpbmUgUm9vdCBDQQIUA+POe3D7qmANSWS/liNW
# J/XK6bEwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKA
# ADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYK
# KwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgEdKH89KovsoKf42Qkqx47I/M7/P7
# s2WatNuUmAOMAjMwCwYHKoZIzj0CAQUABEYwRAIgU7+r9kPOlSupTpMc2PONZr+Z
# m1w/0PM6Q1G4nW5WzN0CIFLbs956JQqXmnH4h6IsRQi7d3+Zg0NN8YIQcSeBWTKw
# oYIDJjCCAyIGCSqGSIb3DQEJBjGCAxMwggMPAgEBMH0waTELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVz
# dGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDv
# GEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2MDIwNDEwNDQyOFowLwYJKoZIhvcN
# AQkEMSIEIBeLjd10pWtYvb2Ezime8ygkJGtqiogUTD5774bZCyv/MA0GCSqGSIb3
# DQEBAQUABIICACGNrDixLw+E+Xb9utnsbNh9rKrOe0Z/TwdSZiHcGM31FprLwzAr
# 7geCS0lJ1uuHikd7wjkpy5kPvNGl4pwlqmOLmZLYvWj7MtpmC+mfdjj6fplRHVXW
# Ki96um2at0UfR6T2VgfjtudlMC50OmZ75nsO8hWGj/rqmbn5L6WSr7TcQTJsIu/l
# b4UeJQCFtW2zfgIUVobsWO4gG4FNtgDbBZu+3hf1dRfYp7UWTTiGGKoRFuIsGMQL
# w9uCXx3T/kVYKxCZJoGVrXPKau25CEMyD24QE824XJK/oWwY56gokkkRJ5kW7lVN
# QXcSMZIWT1gDBglgMGs7lN5GaEKmTfma8152r8oEt1DVnhOq/k5X8DreVE8mqDKg
# F9uRxuWH4PoU2JjYBji0ZaXUUa8MUrIFMCPxN5l6FAO7TEe/2+OXYLNB76kltrif
# PX3tQ7CxW9msbUlZLigrvXDpKLBlIJ2i1laQazT0b4xd8PwzX2MgaTbWbDk3OJSb
# xJAzHZv5XW4WmROlOsughH/qdkXhxmhr47kj1KH/8x7paA+CPMJTwIOxnMJChmIG
# gAplzJ1FKUOcd0DgeNyZCp4J3KyQCQXFe3QsRjuns7tcvPg1mXcuCIUvlKkujcJY
# FqAar1iycFN/KflUekuPhJ8OTvKo4Ry7T9DqK70gByegXuYdhJ63LEZQ
# SIG # End signature block

