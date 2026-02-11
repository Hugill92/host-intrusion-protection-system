# Security Policy

## Supported Versions
We provide security updates for the following versions:

| Version | Supported |
|--------:|:---------:|
| v1.x (latest release) | ✅ |
| Older releases | ❌ |

> Note: Development branches and pre-release builds may change rapidly and are not guaranteed to receive security patches.

## Reporting a Vulnerability
Please report security issues **privately**. Do **not** open a public GitHub Issue for security vulnerabilities.

### Preferred: GitHub Private Vulnerability Reporting
Use GitHub's security reporting feature (Security → Advisories → "Report a vulnerability") if enabled.

### Alternate: Email
Email: **security@YOURDOMAIN.com**  
If you do not have a security mailbox, use a dedicated address you control (not a personal inbox if possible).

Include:
- A clear description of the vulnerability and impact
- Steps to reproduce (PoC if available)
- Affected version(s), Windows build(s), and configuration details
- Logs/redacted evidence when relevant (avoid sensitive secrets)
- Suggested remediation if you have one

### Optional: Encrypted Reports
If you support encryption, add a PGP key here:
- PGP public key: (link or fingerprint)

## Response Targets
We aim to respond within:
- **2 business days**: initial acknowledgement
- **7 business days**: triage assessment and next steps

Timelines may vary depending on severity and complexity.

## Scope
In scope:
- Vulnerabilities that allow bypass of intended security controls
- Privilege escalation, arbitrary code execution, injection, or tampering
- Signature/trust-chain bypass, policy manipulation, or rule poisoning
- Sensitive data exposure (keys, cert material, audit logs with secrets)

Out of scope:
- Social engineering
- Physical access attacks
- Vulnerabilities in third-party dependencies without an exploit path through this project (report upstream first)

## Coordinated Disclosure
We support coordinated disclosure. Please allow a reasonable window for a fix before public disclosure.
We may credit reporters in release notes if requested.

## Security Hardening Notes
This project may use:
- Code signing / AllSigned execution policy
- Reproducible baseline evidence and integrity checks
- Secure configuration defaults

If you suspect a supply-chain or signing-related issue, mark your report **URGENT**.
