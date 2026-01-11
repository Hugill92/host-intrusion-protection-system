[CmdletBinding()]
param(
  [ValidateSet('All','Info','Warning','Critical')]
  [string]$Severity = 'All',
  [int]$EventId = 0,
  [int]$SinceMinutes = 240,
  [string]$TestId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogName = 'FirewallCore'
$CoreRoot = Join-Path $env:ProgramData 'FirewallCore'
$CoreViewsDir = Join-Path $CoreRoot 'User\Views'
$EvViewsDir = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'

New-Item -ItemType Directory -Force -Path $CoreViewsDir | Out-Null
New-Item -ItemType Directory -Force -Path $EvViewsDir   | Out-Null

function Write-QueryListXml {
  param(
    [Parameter(Mandatory)][string]$Log,
    [Parameter(Mandatory)][string]$Select,
    [Parameter(Mandatory)][string]$OutPath
  )

  $xml = "<QueryList>`r`n  <Query Id=`"0`" Path=`"$Log`">`r`n    <Select Path=`"$Log`">$Select</Select>`r`n  </Query>`r`n</QueryList>`r`n"
  Set-Content -LiteralPath $OutPath -Value $xml -Encoding UTF8 -Force
}

$ms = [int64]$SinceMinutes * 60 * 1000
$timeFilter = "TimeCreated[timediff(@SystemTime) <= $ms]"

if ($EventId -gt 0) {
  $select = "*[System[(EventID=$EventId) and $timeFilter]]"
  $name   = "FirewallCore-EventId-$EventId"
} else {
  switch ($Severity) {
    'Info'     { $select = "*[System[(EventID &gt;= 3000) and (EventID &lt;= 3999) and $timeFilter]]"; $name='FirewallCore-Info' }
    'Warning'  { $select = "*[System[(EventID &gt;= 4000) and (EventID &lt;= 4999) and $timeFilter]]"; $name='FirewallCore-Warning' }
    'Critical' { $select = "*[System[(EventID &gt;= 9000) and (EventID &lt;= 9999) and $timeFilter]]"; $name='FirewallCore-Critical' }
    default    { $select = "*[System[$timeFilter]]"; $name='FirewallCore-All' }
  }
}

$coreView = Join-Path $CoreViewsDir ("{0}.xml" -f $name)
$evView   = Join-Path $EvViewsDir   ("{0}.xml" -f $name)

Write-QueryListXml -Log $LogName -Select $select -OutPath $coreView
Copy-Item -LiteralPath $coreView -Destination $evView -Force

$eventvwr = Join-Path $env:SystemRoot 'System32\eventvwr.msc'

try {
  Start-Process -FilePath $eventvwr -ArgumentList ("/v:`"$coreView`"") | Out-Null
} catch {
  Start-Process -FilePath $eventvwr -ArgumentList "/c:$LogName" | Out-Null
}

# SIG # Begin signature block
# MIIFtgYJKoZIhvcNAQcCoIIFpzCCBaMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBN+4wCTov4eS2H
# e58NCuS5Dwr/augQ+g1cgT7eB5rbp6CCAyAwggMcMIICBKADAgECAhAWqBrNbp/s
# q0LWLpUoGJqsMA0GCSqGSIb3DQEBCwUAMCYxJDAiBgNVBAMMG0ZpcmV3YWxsQ29y
# ZSBTY3JpcHQgU2lnbmluZzAeFw0yNjAxMTExMDMzMDBaFw0zNjAxMTExMDQzMDBa
# MCYxJDAiBgNVBAMMG0ZpcmV3YWxsQ29yZSBTY3JpcHQgU2lnbmluZzCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBALanpHAxqchTmDsDelBMMGqhuD/qBCS6
# WBhFkFyipQH1RYozRTLMorh/XyL90qtuHSWc53r1JEwy07Fyeq4VVvpSQpf/kDDx
# fuSpEDKkux9Oqbm0E0fUbCg33kXEPliunM8qnrtz0QKsudVLCSdRc1lzgBNI7vYS
# LoybGQYGSlRKiITXafzKHM3TGp7kxhuc+Fcz1IxTnAd3NRKrUHGfm0p3rflpPL4c
# 8STqXkZCATWtgfkaoCJ6VKbfTn6Plsv54t0rqBmRFfKd5DkmsNrVCdCQk408iBF5
# B9gMtNU+U7Kp9e527JxWcMT5vZaKZ0GhNhYopLJLS+E5CDAtjWH+EgECAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBRo4Db7+Vk/nbKtkGTT9k1im36MhjANBgkqhkiG9w0BAQsFAAOCAQEADoGX2VSj
# mrwdYR7ShaEsj/rtxOBqFDGK1uKMxJAcnjqsD45jhE+fEqMNlvx+Nw7pjxxvLyQd
# zL9JY/hrLgQxdeGCCJyuXxoaOqdDv5UNs9J1UiHd9YitD6Y++GiMCIPNu3JJoUL4
# OmXTs8stDk9jM2m2nbN3vyGOI7SifX+O9cBe6uK/UgiNRQ+D4mSi1A6PsGdPlDcU
# 2QYjt+xT6q6hqgVqgvqWmwrzqkEw1TlQ4d9rVQxmxRH8a2SofdULbbdw6CJJXn4F
# 0Z6fE8KPe1nELXplmRsulgrx1xJJ/mjs7EsVq6tEClQ5Mt0n5RoqxRhfJYGrpo0a
# cEKp1Uw2HG8aQTGCAewwggHoAgEBMDowJjEkMCIGA1UEAwwbRmlyZXdhbGxDb3Jl
# IFNjcmlwdCBTaWduaW5nAhAWqBrNbp/sq0LWLpUoGJqsMA0GCWCGSAFlAwQCAQUA
# oIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcN
# AQkEMSIEIM/iKQ2BZhl9DIJxa/sgMYot8rVTBWx1V3yF2ZsfTEQfMA0GCSqGSIb3
# DQEBAQUABIIBAKRKRI/VpRdkZ+SlQiyWUtt43Lzy9Pm3igQ+PPAmn5R+DExxZV11
# 9Z96CmuBh4tOJjXwzZiY427Bmf09zu7l+jbsF0YlyH5WJmEaFk+9ZVq9V7ciL3OL
# uLHEoOMCdOvO33t/TqTgnIpaJtxTnzFDmHds0LCb36c4VRjJHGswp/3UEnwo97NQ
# M1Rgx5R9jHcO95b/w7/1XocNgB+r1qmFP11ykZWtU0FIeB/XN0lj5EzUgX17GXbZ
# CybpvwWmRb8hFut69Z9UeO4r1cnWAAjPVGzLW+ylWqOeVKAHteD6tAdAK/G3kcOA
# TeCkZVfx/AEnKU6k/7Y2DJ8ozY9gV6e7Ca8=
# SIG # End signature block
