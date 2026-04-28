---
name: session-latched-display-state
description: Use when UI text or derived display state flickers because the source updates sparsely, emits temporary empties, or becomes briefly weaker than the current trusted session.
---

# Session-Latched Display State

Keep display state latched to session validity, not to raw update frequency.

## A. The Generic Pattern / Methodology

| Item | Guidance |
| --- | --- |
| Core Concept | Treat user-visible text and status as a session-level state machine with trust, grace periods, and explicit reset conditions. |
| Universal Checklist | 1. Define what keeps a session trustworthy. 2. Separate `session active` from `new text arrived`. 3. Keep a stable displayed snapshot through brief weak windows. 4. Keep surface-specific display policy local. 5. Reset only on real source loss or session change. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| DymicShell lyrics display | Sparse lyric timing and weak browser payloads made compact and expanded views flash back to metadata, stale text, or the wrong lyric line even though the same song session was still active. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Expire trust whenever the current field stops changing for a while, or choose display text from one big mixed fallback chain across tracks and surfaces. |
| ✅ The Best Practice (The Fix) | Latch display to session validity, preserve a same-surface stable snapshot, and resolve fallback only within the selected track or policy for that surface. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- A sparse stream is not the same as a dead stream.
- Pick one authoritative track or source before considering fallback.
- Different surfaces can share a model without sharing one fallback policy.
- Do not let display-only text changes trigger unrelated artwork or metadata transitions.
- When providers disagree briefly, prefer the source that owns the authoritative timeline or session identity.

### Warning Signs

- A single fallback chain mixes current, next, cached, original, translated, and metadata values.
- UI flicker happens near gaps, pauses, or source handoff boundaries.
- One-line and two-line surfaces share identical text-selection logic.
- A temporary empty payload causes a full visual mode change.

## E. Universal Verification Strategy

| Check | Goal |
| --- | --- |
| Simulate long gaps between meaningful updates | Confirm the UI does not fall back early. |
| Pause mid-session | Confirm the displayed snapshot stays stable. |
| Flip source preference | Confirm the UI changes deliberately, not through mixed fallback drift. |
| Compare visible output changes vs internal updates | Confirm each surface changes only when its own visible output changes. |
| `timeout 5 qs --path .` | Confirm shell still loads. |

## References

- `services/MediaControlService.qml`
- `modules/bar/widgets/MediaControlWidget.qml`
- `modules/bar/media/MediaPanelContent.qml`
- `services/NeteaseWebLyricsService.qml`
