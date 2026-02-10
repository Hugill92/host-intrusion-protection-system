# Admin Toolkit – System Repair + Registry Optimizations

This package contains **two** things:

1. **System Repair** (DISM + SFC) – fixes Windows component store / system file corruption.
2. **Registry Optimizations** – applies a **small, explicit** set of performance-oriented registry values, then (optionally) verifies them.

> ✅ Everything must be run **as Administrator**.

---


---

## Optional: Cross-Device Resume (iPhone / non-Android users)

If you **do not use Android cross-device resume features** (common for iPhone users on Windows), you can disable **Cross-Device Resume** for your Windows user profile.

### Recommended (safe) option
- Run: `Optimization\Optional_Disable-CrossDeviceResume.cmd`  
  This sets:

- `HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration`
- `IsResumeAllowed = 0`  *(0=off, 1=on)*

To undo:
- Run: `Optimization\Optional_Enable-CrossDeviceResume.cmd` *(sets it back to 1)*

### Advanced option (optional): ViVeTool feature flag
If you also extracted the **ViVeTool bundle** into `Optimization\Tools\ViveTool`, you can run:

- `Optimization\Optional_Disable-CrossDeviceResume_ViveTool.cmd`

⚠️ ViVeTool toggles feature flags and is not an official Microsoft-supported mechanism. It may require a reboot and behavior can vary by Windows build. Use at your own risk.

Send-back logs for this step are written into:
- `Optimization\Logs\CrossDeviceResume_*.*`


## Contents

- `System-Repair.cmd`
- `Optimization\`
  - `Run-Registry-Optimization-Full.cmd` ✅ **Recommended**
  - `Run-Registry-Optimizations.cmd` (apply-only / advanced)
  - `Registry_Optimizations.ps1` (the actual registry changes + log bundle output)
  - `Verify-RegistryOptimizations.ps1` (verification-only)
  - `_legacy\` (old apply scripts kept for reference; not recommended)

---

## What should I run?

### ✅ For most people (what I recommend you tell the recipient)
Run:

1) **System Repair (optional, only if the machine is unstable):**
- `System-Repair.cmd`

2) **Registry Optimizations (recommended path):**
- `Optimization\Run-Registry-Optimization-Full.cmd`
- `Optimization\Run-Registry-Optimization-Full-PlusCrossDeviceResume.cmd` *(optional)*

### Why “FULL” is the right default
`Run-Registry-Optimization-Full.cmd` does **everything** in one go:

- Applies the registry changes
- Generates a **send-back log bundle** in the same folder
- Runs a verification pass (PASS/FAIL per value)

### When to use “Run-Registry-Optimizations.cmd”
Use `Run-Registry-Optimizations.cmd` only if you want **apply-only** (no verification step), or if you’re automating/testing and want to pass PowerShell args (e.g., `-WhatIf`).

---

## Logs / “send this back to me” bundle 📦

After running the **FULL** optimization, send back:

- `Optimization\Logs\RegistryOptimization_*.json`
- `Optimization\Logs\RegistryOptimization_*.md`
- `Optimization\Logs\RegistryOptimization_*.txt`
- `Optimization\RegistryOptimization_Verification_*.log`
- `Optimization\Backups\*.reg`

The scripts also write an audit copy to:
- `C:\ProgramData\RegistryOptimizations` (local audit trail)

System repair logs are written to:
- `C:\Windows\Logs\SystemRepair\Repair_*.log`
- `C:\Windows\Logs\SystemRepair\Repair_*.json`

---

## Registry changes included (explicit callouts only)

The optimization scripts touch **only** these values:

| Area | Registry Path | Value | Type | Target |
|---|---|---|---|---|
| Multimedia/SystemProfile | `HKLM\...\Multimedia\SystemProfile` | `NetworkThrottlingIndex` | DWORD | `0xFFFFFFFF` |
| Multimedia/SystemProfile | `HKLM\...\Multimedia\SystemProfile` | `SystemResponsiveness` | DWORD | `0x00000000` |
| Services | `HKLM\SYSTEM\CurrentControlSet\Control` | `SvcHostSplitThresholdInKB` | DWORD | `0x001000000` |
| PriorityControl | `HKLM\...\PriorityControl` | `Win32PrioritySeparation` | DWORD | `0x00000026` |
| Games Task Profile | `HKLM\...\Tasks\Games` | `GPU Priority` | DWORD | `0x00000008` |
| Games Task Profile | `HKLM\...\Tasks\Games` | `Priority` | DWORD | `0x00000002` |
| Games Task Profile | `HKLM\...\Tasks\Games` | `Scheduling Category` | String | `High` |
| Games Task Profile | `HKLM\...\Tasks\Games` | `SFIO Priority` | String | `High` |
| Power Setting Subkey | `HKLM\...\PowerSettings\...\0cc5b647-...` | `ValueMax` | DWORD | `0x00000000` |

**Non-changes explicitly respected:**
- Games key: does **NOT** set Affinity, Background Only, or Clock Rate
- PowerSettings key: does **NOT** set `Attributes`

---

## Rollback / safety notes 🛟

- A reboot is recommended after applying the registry changes.
- Before applying, the script exports `.reg` backups into:
  - `Optimization\Backups\`
- To rollback: import the relevant `.reg` file (right-click → Merge) or restore from your preferred restore-point/backup process.

---

## Offline image repair (optional)

`System-Repair.cmd` supports repairing an **offline** Windows image (mounted to a folder), e.g.:

```
System-Repair.cmd "D:\MountedImage"
```

The folder must contain a `Windows\` subfolder.

---

## Support expectations

If anything fails:
1. Re-run as Administrator
2. Reboot
3. Send the log bundle back (paths above)
