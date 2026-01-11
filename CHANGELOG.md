Save-ClipboardFile .\CHANGELOG.md


## 2026-01-10 Notifiers signoff sprint

### Added / Improved
- Notifier queue pipeline stabilized: JSON payloads written to ProgramData queue and moved through Pending → Processing → Processed/Reviewed/Working as listener handles them.
- Toast listener runs in **user session** (STA) and renders WinRT toasts; WAV playback is app-controlled (no Windows system toast sound).
- Custom protocol activation added: **firewallcore-review://** for toast actions (Review Log / Details) via C:\Firewall\User\FirewallToastActivate.ps1.
- Warning dialog timing adjusted: Warning dialog auto-close set to **20s**, reminders remain **10s** for manual review loop behavior.
- Send-FirewallNotification enhanced to support UX routing (Toast vs Dialog) while preserving SchemaVer=1 payload format.

### Known Issues / Regressions Observed
- WinRT toast popups intermittently suppressed (Show() returns OK but no visible banner). Registry enables (ToastEnabled/ShowBanner) may persist, but shell-host state can still prevent popups; reboot and shell-host restart used during troubleshooting.

### Experiments (Rolled Back)
- Kafka producer module (Confluent.Kafka) attempted for streaming notification events. Blocked by native dependency packaging issues (librdkafka load failure) and config schema edge cases; Kafka integration disabled and module removed pending a clean packaging plan.

