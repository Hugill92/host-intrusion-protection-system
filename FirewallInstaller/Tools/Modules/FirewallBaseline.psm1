Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FwRuleFingerprint {
  [CmdletBinding()]
  param(
    [string]$PolicyStore = "ActiveStore",

    [Parameter(Mandatory, ParameterSetName="RuleRecords")]
    [object[]]$RuleRecords,

    [Parameter(Mandatory, ParameterSetName="InventoryJson")]
    [string]$InventoryJsonPath
  )

  function Get-StringOrEmpty {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    try { return $Value.ToString() } catch { return "" }
  }

  function Get-FingerprintFromRecords {
    param(
      [Parameter(Mandatory)][object[]]$Records,
      [Parameter(Mandatory)][string]$PolicyStoreLabel
    )

    $lines = foreach ($r in $Records) {
      $display = Get-StringOrEmpty $r.DisplayName
      $dir     = Get-StringOrEmpty $r.Direction
      $action  = Get-StringOrEmpty $r.Action
      $enabled = Get-StringOrEmpty $r.Enabled
      $profile = Get-StringOrEmpty $r.Profile
      $group   = Get-StringOrEmpty $r.Group
      "{0}|{1}|{2}|{3}|{4}|{5}" -f $display, $dir, $action, $enabled, $profile, $group
    }

    $sorted = $lines | Sort-Object
    $joined = ($sorted -join "`n")

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    $sha.Dispose()

    return [pscustomobject]@{ PolicyStore=$PolicyStoreLabel; Count = $lines.Count; Sha256 = $hash; Error = $null }
  }

  try {
    if ($PSCmdlet.ParameterSetName -eq "RuleRecords") {
      return (Get-FingerprintFromRecords -Records $RuleRecords -PolicyStoreLabel $PolicyStore)
    }

    if ($PSCmdlet.ParameterSetName -eq "InventoryJson") {
      if (-not (Test-Path -LiteralPath $InventoryJsonPath)) {
        return [pscustomobject]@{ PolicyStore="<inventory-json>"; Count = -1; Sha256 = "<error>"; Error = "Inventory JSON missing: $InventoryJsonPath" }
      }

      $inv = Get-Content -LiteralPath $InventoryJsonPath -Raw | ConvertFrom-Json
      if (-not $inv -or -not $inv.Rules) {
        return [pscustomobject]@{ PolicyStore="<inventory-json>"; Count = -1; Sha256 = "<error>"; Error = "Inventory JSON missing Rules[]: $InventoryJsonPath" }
      }

      return (Get-FingerprintFromRecords -Records @($inv.Rules) -PolicyStoreLabel $PolicyStore)
    }

    $rules = Get-NetFirewallRule -PolicyStore $PolicyStore -ErrorAction Stop
  } catch {
    return [pscustomobject]@{ PolicyStore=$PolicyStore; Count = -1; Sha256 = "<error>"; Error = $_.Exception.Message }
  }

  $records = foreach ($r in $rules) {
    [pscustomobject]@{
      DisplayName = $r.DisplayName
      Direction   = $r.Direction
      Action      = $r.Action
      Enabled     = $r.Enabled
      Profile     = $r.Profile
      Group       = $r.Group
    }
  }

  return (Get-FingerprintFromRecords -Records $records -PolicyStoreLabel $PolicyStore)
}

function Get-Sha256Hex {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function New-FirewallBaselineManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BaselineDir,
    [Parameter(Mandatory)][string[]]$Files,
    [string]$Type = "PREINSTALL",
    [string]$PolicyStore = "ActiveStore",
    [string[]]$Warnings = @(),
    [string]$InventoryJsonName = ""
  )

  $manifestPath = Join-Path $BaselineDir "FirewallBaseline.manifest.sha256.json"

  $items = @()
  foreach ($f in $Files) {
    $p = Join-Path $BaselineDir $f
    if (-not (Test-Path $p)) { throw ("Manifest target missing: " + $p) }
    $fi = Get-Item -LiteralPath $p
    $items += [pscustomobject]@{
      Name   = $f
      Bytes  = [int64]$fi.Length
      Sha256 = (Get-Sha256Hex -Path $p)
    }
  }

  $fpSource = "PolicyStore"
  if ($InventoryJsonName) {
    $invPath = Join-Path $BaselineDir $InventoryJsonName
    if (Test-Path -LiteralPath $invPath) {
      $fpSource = "InventoryJson"
      $fp = Get-FwRuleFingerprint -InventoryJsonPath $invPath -PolicyStore $PolicyStore
    } else {
      $fp = Get-FwRuleFingerprint -PolicyStore $PolicyStore
    }
  } else {
    $fp = Get-FwRuleFingerprint -PolicyStore $PolicyStore
  }

  if ($fp.Error -or $fp.Sha256 -eq "<error>") {
    throw ("Failed to compute firewall fingerprint: {0}" -f $fp.Error)
  }

  $obj = [ordered]@{
    Type      = $Type
    CreatedAt = (Get-Date).ToString("o")
    Computer  = $env:COMPUTERNAME
    User      = $env:USERNAME
    Warnings  = $Warnings
    Files     = $items
    FirewallFingerprint = [ordered]@{
      Source     = $fpSource
      PolicyStore = $fp.PolicyStore
      Count       = $fp.Count
      Sha256      = $fp.Sha256
      Error       = $fp.Error
    }
  }

  ($obj | ConvertTo-Json -Depth 10) | Set-Content -Path $manifestPath -Encoding UTF8
  return $manifestPath
}

function Test-FirewallBaselineManifest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BaselineDir,
    [string]$PolicyStore = "ActiveStore",
    [string]$InventoryJsonName = "Firewall-Policy.json"
  )

  $manifestPath = Join-Path $BaselineDir "FirewallBaseline.manifest.sha256.json"
  if (-not (Test-Path $manifestPath)) {
    return [pscustomobject]@{ Ok=$false; Failures=@("Missing manifest: FirewallBaseline.manifest.sha256.json"); ManifestPath=$manifestPath }
  }

  $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $fail = New-Object System.Collections.Generic.List[string]

  foreach ($it in $m.Files) {
    $p = Join-Path $BaselineDir $it.Name
    if (-not (Test-Path $p)) { $fail.Add(("Missing file: " + $it.Name)); continue }
    $h = (Get-Sha256Hex -Path $p)
    if ($h -ne ($it.Sha256.ToString().ToLowerInvariant())) {
      $fail.Add(("Hash mismatch: {0}" -f $it.Name))
    }
  }

  $fpNow = $null
  $fpComputedFrom = "PolicyStore"
  $wantSource = $null
  try { $wantSource = $m.FirewallFingerprint.Source } catch {}

  if ($wantSource -eq "InventoryJson") {
    $invPath = Join-Path $BaselineDir $InventoryJsonName
    $fpComputedFrom = "InventoryJson"
    $fpNow = Get-FwRuleFingerprint -InventoryJsonPath $invPath -PolicyStore $PolicyStore
  } else {
    $fpNow = Get-FwRuleFingerprint -PolicyStore $PolicyStore
  }

  if ($fpNow.Error -or $fpNow.Sha256 -eq "<error>") {
    $fail.Add(("Firewall fingerprint compute error (computed from {0}): {1}" -f $fpComputedFrom, $fpNow.Error))
  }

  if ($m.FirewallFingerprint -and $m.FirewallFingerprint.Sha256) {
    $expect = $m.FirewallFingerprint.Sha256.ToString().ToLowerInvariant()
    if ($fpNow.Sha256 -ne $expect) {
      $fail.Add(("Firewall fingerprint mismatch (computed from {0})" -f $fpComputedFrom))
    }
  } else {
    $fail.Add("Manifest missing FirewallFingerprint.Sha256")
  }

  return [pscustomobject]@{
    Ok         = ($fail.Count -eq 0)
    Failures   = $fail
    ManifestPath = $manifestPath
    FingerprintNow = $fpNow
    FingerprintComputedFrom = $fpComputedFrom
  }
}

Export-ModuleMember -Function Get-FwRuleFingerprint,New-FirewallBaselineManifest,Test-FirewallBaselineManifest

# SIG # Begin signature block
# MIIEkgYJKoZIhvcNAQcCoIIEgzCCBH8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAMOrk/FGjH/X44
# QtMrPKAzVVaX50dDtMdFHeeyDjwz36CCArUwggKxMIIBmaADAgECAhQD4857cPuq
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
# ggEzMIIBLwIBATA/MCcxJTAjBgNVBAMMHEZpcmV3YWxsQ29yZSBPZmZsaW5lIFJv
# b3QgQ0ECFAPjzntw+6pgDUlkv5YjVif1yumxMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IH9O8OnwH0I1uAJtAd1mCFv4EHCXq5fqEQdTkXUNmm1sMAsGByqGSM49AgEFAARG
# MEQCIFbnHt/UVZXxUpPgsCASjhRRGU2+nPkCJkoXRuERdk3uAiBAK9Kyoabqgrvn
# UGkXhLNe6ETJTiXFpvJOhUQcfH0/7w==
# SIG # End signature block
