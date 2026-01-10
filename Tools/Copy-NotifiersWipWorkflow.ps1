param(
    [string]$BaseBranch = "dev/notifiers",
    [string]$WorkBranch = "dev/notifiers-wip2"
)

$now      = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$current  = (& git rev-parse --abbrev-ref HEAD 2>$null)
$head     = (& git rev-parse --short HEAD 2>$null)

$txt = @"
### Notifiers WIP workflow (generated $now)

**Current:** $current ($head)  
**Base:** $BaseBranch  
**Work:** $WorkBranch  

#### Before starting work
```powershell
git checkout $WorkBranch
git pull
git status
```

#### WIP loop (after test-validated chunk)
```powershell
git status
git add -A
git commit -m "notifiers: <what changed> (tested: <test name>)"
git push
```

#### When ready to merge
Open PR:
- base: $BaseBranch
- compare: $WorkBranch
Recommended merge: Squash and merge
"@

Set-Clipboard -Value $txt
Write-Host "[OK] Copied Notifiers WIP workflow to clipboard."
