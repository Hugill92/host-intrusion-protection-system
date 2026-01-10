Set-StrictMode -Version Latest

$script:MutexName = "Global\FirewallInstaller_Exclusive"

function Enter-FirewallExclusive {
    $script:Mutex = New-Object System.Threading.Mutex($false, $script:MutexName)
    if (-not $script:Mutex.WaitOne(30000)) {
        throw "Firewall exclusive lock timeout (another component is active)"
    }
}

function Exit-FirewallExclusive {
    if ($script:Mutex) {
        $script:Mutex.ReleaseMutex()
        $script:Mutex.Dispose()
        $script:Mutex = $null
    }
}

Export-ModuleMember -Function Enter-FirewallExclusive, Exit-FirewallExclusive
