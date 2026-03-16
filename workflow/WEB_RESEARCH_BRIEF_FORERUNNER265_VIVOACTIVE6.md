[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Web-Verified Research Brief (Pre-Coding)

Goal: lock down the most reliable public facts before writing code for **Forerunner 265** and **vívoactive 6**.

Last refreshed: 2026-03-16.

---

## 1) Device facts verified from Garmin Developer site
Source: Garmin Connect IQ **Compatible Devices** page.

- **Forerunner 265**: `416 x 416`, round, AMOLED, **API Level 5.2**.
- **Forerunner 265s**: `360 x 360`, round, AMOLED, **API Level 5.2**.
- **vívoactive 6**: `390 x 390`, round, AMOLED, **API Level 5.2**.

Why this matters:
- You can standardize around **CIQ API 5.2** features for both target devices.
- You still need per-device layout tuning because the resolutions are different.

Reference:
- https://developer.garmin.com/connect-iq/compatible-devices/

---

## 2) Watch-face update behavior and hard runtime constraints
Source: Garmin Connect IQ FAQ ("How do I Make My Watch Face Update Every Second?").

Verified points:
- Since API 2.3, supported devices can call `onPartialUpdate()` every second.
- `onPartialUpdate()` has strict execution limits.
- If exceeded, `onPowerBudgetExceeded()` is invoked and partial updates stop for the rest of the app lifecycle.
- Garmin explicitly recommends `Dc.setClip()` and using `BufferedBitmap` prepared during `onUpdate()`.

Implication for production watchfaces:
- Keep every-second drawing to very small clip regions.
- Pre-render any expensive elements outside `onPartialUpdate()`.

Reference:
- https://developer.garmin.com/connect-iq/connect-iq-faq/

---

## 3) AMOLED always-on behavior (burn-in / luminance protection)
Source: Garmin Connect IQ FAQ ("How do I Make a Watch Face for AMOLED Products?").

Verified points:
- Burn-in protection applies when a CIQ watch face is foreground + device is in sleep mode.
- Original Venu rule described by Garmin: screen can shut off if **more than 10% of pixels are on** or **any pixel is on longer than 3 minutes**.
- Garmin also notes newer behavior (since Venu 2 generation): always-on rule is framed as **<10% of screen luminance**.
- Use `DeviceSettings.requiresBurnInProtection` and (on newer products) `System.getDisplayMode()` to branch rendering behavior.

Implication for FR265 + vívoactive 6:
- Treat low-power mode as a separate rendering system, not a dimmed clone of high-power mode.
- Design for sparse, shifting, black-dominant AOD visuals.

Reference:
- https://developer.garmin.com/connect-iq/connect-iq-faq/

---

## 4) Toolchain facts for your Windows 10 + VS Code setup
Sources: Garmin SDK page + VS Code requirements page.

Verified points:
- Garmin SDK flow includes SDK Manager downloads for Windows and installation of Garmin's **Monkey C** extension in VS Code.
- Garmin docs explicitly walk through `Monkey C: Verify Installation` in VS Code.
- VS Code requirements list **Windows 10 and 11 (64-bit)**.

Implication:
- Your Windows 10 + VS Code setup is valid for the core CIQ workflow.
- Prioritize SDK Manager + VS Code extension verification before coding sessions.

References:
- https://developer.garmin.com/connect-iq/sdk/
- https://code.visualstudio.com/docs/supporting/requirements

---

## 5) Multi-model research workflow (ChatGPT + Claude + Gemini)
Goal: maximize correctness before implementation.

### Evidence-backed prompt guidance we validated
- Anthropic docs emphasize prompt techniques such as clarity, examples, XML structuring, role prompting, and prompt chaining.
- Google Gemini docs strongly recommend clear/specific instructions and frequent use of few-shot examples.

References:
- https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview
- https://ai.google.dev/gemini-api/docs/prompting-strategies

### Practical review loop for this repo
1. **Grounding pass (Gemini/Claude/ChatGPT):** ask each model for source-backed claims only, with URLs.
2. **Cross-model diff:** compare disagreements and unresolved claims.
3. **Primary-source arbitration:** prefer Garmin Developer docs over forum/blog claims.
4. **Repo write-up update:** append only claims that survived arbitration.
5. **Pre-code checklist:** freeze assumptions for device resolution, API level, AOD behavior, and update-frequency constraints.

---

## 6) Open items to keep re-verifying
- Exact per-device heap and memory budget values for FR265 and vívoactive 6 are not exposed in the compatible devices table; verify via active SDK device definitions and simulator diagnostics.
- UX/App Store policy interpretation can change; re-check app review and UX guidance before publishing.

---

## 7) "Do this before coding" checklist
- [ ] Confirm target compiler setting includes FR265 + vívoactive 6 in project config.
- [ ] Validate low-power/AOD rendering path separately from high-power rendering.
- [ ] Add instrumentation around `onPartialUpdate()` work and clip bounds.
- [ ] Simulate burn-in / heat map before first device sideload.
- [ ] Keep all performance-sensitive assumptions documented with source links.
