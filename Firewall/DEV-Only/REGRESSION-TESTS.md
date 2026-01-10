
---

# 🧪 REGRESSION TEST MATRIX (FINAL)

Run **after every change**.

## C1 – Observe
- Generate blocked traffic
- Expect:
  - Event 3400
  - No firewall rules

## C2 – Temp Block
- Trigger threshold
- Expect:
  - Event 3401
  - `WFP-TEMP-BLOCK::*`
  - Auto-removal after timeout

## C3 – Persistent
- Trigger 3 strikes
- Expect:
  - Event 3402
  - `WFP-PERSISTENT-BLOCK::*`
  - Rule persists after reboot

## C4 – Deny Hash
- Add hash to `wfp.denyhash.json`
- Run monitor
- Expect:
  - Event 3404
  - Immediate persistent block
  - Entry in `wfp.blocked.json`

---