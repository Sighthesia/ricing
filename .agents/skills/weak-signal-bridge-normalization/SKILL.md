---
name: weak-signal-bridge-normalization
description: Use when a browser, extension, or cross-context bridge emits incomplete payloads, placeholder data, or out-of-order identifiers that must be normalized before entering core app state.
---

# Weak-Signal Bridge Normalization

Treat incoming bridge payloads as hints that must be normalized before they become trusted state.

## A. The Generic Pattern / Methodology

| Item | Guidance |
| --- | --- |
| Core Concept | Build a normalization boundary that scores payload trust, filters placeholders, preserves stronger session state, and recovers missing identifiers conservatively. |
| Universal Checklist | 1. Define authoritative vs optional vs placeholder fields. 2. Reject bootstrap-only payloads before app state. 3. Invalidate stale sessions explicitly on identity changes. 4. Preserve stronger current state when a new payload is weaker. 5. Add a conservative recovery path for delayed identifiers. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| NetEase lyrics bridge in DymicShell | Track changes often delivered title and artist before `songId`, while probe placeholders and cross-context messaging quirks caused broken lyric recovery and stale bridge state. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Treat every bridge event as complete and authoritative, or forward placeholder/debug metadata into normal state. |
| ✅ The Best Practice (The Fix) | Normalize at the boundary, rank payload quality, ignore placeholders, preserve stronger sessions, and recover missing identity only with conservative fallback logic. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- External bridges should publish normalized app events, not raw probe noise.
- Cross-context message boundaries are reliability boundaries; provide a fallback path when the environment is flaky.
- A newer payload with fewer identity fields is not automatically a better payload.
- Keep display-latching logic separate from source-normalization logic.
- Injected code must redeclare every constant it needs inside the injected execution context.

### Warning Signs

- Payloads contain debug markers, URLs, or bootstrap literals in business-data fields.
- Metadata updates arrive before stable identity fields and break downstream recovery.
- Message listeners work only after reinstall or hard reload.
- Probe code silently loses access to outer-scope constants.

## E. Universal Verification Strategy

| Check | Goal |
| --- | --- |
| Simulate late identity arrival | Verify recovery without reusing stale session data. |
| Inspect normalized app state | Verify placeholders never enter trusted state. |
| Force one transport to fail | Verify fallback transport still reaches the bridge. |
| Send a weaker payload during an active session | Verify downstream consumers keep the stronger session. |
| `timeout 5 qs --path .` | Confirm shell still loads. |

## References
- `scripts/tampermonkey/netease-web-lyrics.user.js`
- `scripts/tampermonkey/netease-web-lyrics.md`
- `scripts/firefox-extensions/netease-web-lyrics/background.js`
- `scripts/firefox-extensions/netease-web-lyrics/content-script.js`
- `scripts/firefox-extensions/netease-web-lyrics/page-probe.js`
- `services/NeteaseWebLyricsService.qml`
