---
name: baseline-cache-before-transition
description: Use when a fallback, return target, or baseline measurement is currently computed from a live value that becomes invalid as soon as a new mode or transition starts, so later phases need a cached pre-transition snapshot instead.
---

# Baseline Cache Before Transition

When a later transition phase still depends on an earlier steady-state measurement, cache that baseline during the last trustworthy pre-transition window instead of recomputing it live after the mode flip.

## A. The Generic Pattern / Methodology

| Item | Guidance |
| --- | --- |
| Core Concept | Separate **measurement time** from **consumption time** whenever the value is only trustworthy before a transition or mode change starts. |
| Universal Checklist | 1. Identify which baseline is only valid in the pre-transition state. 2. Identify exactly when that live source becomes weaker or invalid. 3. Cache the baseline during the last trustworthy window. 4. Latch transition-time consumers from the cache, not from the expired live source. 5. Release or refresh the cache only when a new trustworthy baseline exists. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| SuperIsland width collapse | A `bar-expanded window-hint` exit kept collapsing to a tiny transient width because the fallback idle width was represented as a live value that dropped to `0` once hint mode activated, but the latch ran after that activation. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Compute a fallback or return target from live state during the transition phase even though that live source only stays valid in the earlier steady state. |
| ✅ The Best Practice (The Fix) | Cache the stable baseline during the trustworthy pre-transition phase, then let the transition consume the cached or latched snapshot after the mode changes. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- A value that is correct only before mode entry is not a reliable fallback during mode exit.
- If the consumer runs after a phase flip, it should not depend on a source that the phase flip invalidates.
- Treat baseline measurements, return targets, and collapse widths as snapshot candidates whenever live state can be replaced by transient content.
- Prefer one explicit cached baseline over several weak fallback reads from partially-transitioned state.
- If the first latch attempt can happen before measurement is ready, allow a later trustworthy refresh to fill an empty cache without letting weaker post-transition values overwrite it.

### Warning Signs

- Logs show the fallback or latched value is `0` or tiny exactly when a new mode becomes active.
- A transition animates correctly but heads toward the wrong target width, height, or position.
- The same property is described as "safe" or "idle" but is implemented as a gated live computation.
- Fix attempts that only retune easing, duration, or cleanup timing do not change the bad target value.

## E. Universal Verification Strategy

| Check | Goal |
| --- | --- |
| Log live baseline, cached baseline, and latched transition target separately | Confirm exactly which source becomes invalid and which one survives mode entry. |
| Reproduce the entry path and the exit path in one run | Confirm the cached baseline is captured before invalidation and reused later. |
| Force the transient content to report a very small measurement | Confirm the return/collapse target still prefers the cached steady-state baseline. |
| Repeat the transition twice | Confirm the cache refreshes only from trustworthy steady-state windows and does not keep stale junk forever. |
| `timeout 5 qs --path .` | Confirm shell still loads. |

## References

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/SuperIslandTrackGeometry.qml`
