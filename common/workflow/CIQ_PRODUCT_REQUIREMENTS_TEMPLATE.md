[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Garmin Connect IQ Product Requirements Template (1-Page)

Use this as the required pre-build spec for watchfaces/widgets/apps targeting Garmin CIQ.

---

## 1) Product Snapshot
- **Project Name:**
- **App Type:** (Watch Face / Widget / Device App / Data Field)
- **Owner:**
- **Version Target:**
- **Primary Devices:** (e.g., Forerunner 265, vívoactive 6)
- **Minimum API Level:**
- **Release Goal Date:**

## 2) Problem + Success Criteria
- **User Problem (1–2 sentences):**
- **Primary Use Cases (top 3):**
  1.
  2.
  3.
- **Success Metrics:**
  - Activation / install KPI:
  - 7-day retention KPI:
  - Crash-free sessions KPI:
  - Battery impact KPI:

## 3) Feature Matrix (Must / Should / Could)
| Feature | Priority | User Value | Runtime Cost | Notes |
| :--- | :---: | :--- | :--- | :--- |
| Time display / core info | Must |  | Low |  |
| Health/fitness glanceables | Should |  | Medium |  |
| Personalization options | Should |  | Medium |  |
| Animation / effects | Could |  | High | Disable in low power if needed |
| Online data integration | Could |  | High | Needs robust fallback |

## 4) AOD Contract (Watch Face only)
Define exactly what happens in low-power mode.

- **Low-Power Content Allowed:**
- **Low-Power Content Removed:**
- **Pixel/Luminance Strategy:** (black-first, sparse lines, minimal lit area)
- **Static Pixel Mitigation:** (minute-level shifting / alternating mask)
- **Display Mode Branching:** (`System.getDisplayMode()` + fallback strategy)
- **AOD Fail-Safe:** What content is dropped first if power/burn-in risk rises?

## 5) Redraw Budget Contract
- **`onUpdate()` target time:** `<= ____ ms`
- **`onPartialUpdate()` target avg:** `<= ____ ms` (must stay well below platform threshold)
- **Partial Update Clip Regions:** list exact regions updated each second
- **Buffered Rendering Plan:** what is pre-rendered outside partial updates?
- **Budget Exceeded Behavior:** how app degrades when partial updates are disabled

## 6) Memory Budget Contract
- **Observed Memory Ceiling (by target):**
  - FR265:
  - vívoactive 6:
- **Planned Peak Runtime Usage:**
- **Largest Objects/Resources:**
- **Bitmap Strategy:** (dimensions, color depth, reuse policy)
- **Allocation Discipline:** (no per-second object churn, cache policy)
- **Leak Risk Review:** circular refs, long-lived delegates/listeners

## 7) Test Matrix (Pre-Release Gate)
| Test Area | FR265 | vívoactive 6 | Pass/Fail | Notes |
| :--- | :---: | :---: | :---: | :--- |
| Launch + first render |  |  |  |  |
| Wake/sleep transitions |  |  |  |  |
| AOD burn-in/luminance simulation |  |  |  |  |
| 1Hz partial update stability |  |  |  |  |
| Battery impact spot-check |  |  |  |  |
| Memory pressure scenario |  |  |  |  |
| Sensor unavailable fallback |  |  |  |  |
| App restart/state restore |  |  |  |  |

## 8) Risks + Mitigations
- **Top Risk 1:**
  - Mitigation:
- **Top Risk 2:**
  - Mitigation:
- **Top Risk 3:**
  - Mitigation:

## 9) Go / No-Go Checklist
- [ ] Scope is frozen for v1
- [ ] AOD contract verified on both targets
- [ ] Redraw budget validated with diagnostics
- [ ] Memory budget validated under realistic data load
- [ ] Test matrix complete and passing
- [ ] Release notes + known limitations documented
