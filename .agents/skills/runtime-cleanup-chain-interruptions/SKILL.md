---
name: runtime-cleanup-chain-interruptions
description: Use when visible state appears to reset correctly, but stale reservation, geometry, or shared service state persists because a runtime error interrupts the cleanup chain before the final propagation step.
---

# Runtime Cleanup Chain Interruptions

When a bug looks like stale geometry or stale shared state, first verify that the cleanup chain actually reaches its final propagation step. A runtime error in the middle of exit completion can leave the UI looking half-reset while services and outer containers still hold the old state.

## A. The Generic Pattern / Methodology

### Core Concept

This pattern covers state machines where cleanup happens in multiple layers:

- a local visual owner clears its own state,
- a callback/finalizer propagates the cleared value outward,
- a shared service or outer shell consumes that propagated value.

If a runtime exception stops the finalizer, the inner state may already read as `0` / `false` / `idle`, while the outer reservation or service value stays stale.

### Universal Checklist

1. Trace the cleanup chain from local visual state to outer shared state.
2. Log the local value, the propagated value, and the final consumer value separately.
3. Check runtime warnings/errors before assuming the geometry math is wrong.
4. Confirm that the finalizer callback is actually imported and callable.
5. Fix the interruption before changing fallback math or adding intercept layers.

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| SuperIsland `window-hint` re-entry | The attached panel visibly collapsed and local reservation values reached zero, but the outer bar window still kept stale reserved height because the exit-completion callback crashed before the cleared state propagated into `BarLayoutService`. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Keep tweaking geometry formulas, hit areas, or wrapper exports after the local owner already reports the correct reset value. This treats a propagation failure like a geometry bug. |
| ✅ The Best Practice (The Fix) | Verify whether the cleanup callback chain completes. If a runtime error interrupts the finalizer, repair the callback/import path first, then re-check whether the stale outer state disappears without further geometry changes. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- Separate **local reset success** from **outer propagation success**.
- Whenever stale service state survives after local UI state resets, inspect callback/finalizer execution before editing formulas.
- In multi-step exit flows, import/runtime namespace failures are state-ownership bugs, not just syntax bugs.
- If the outer owner is fed by a callback such as `complete*`, `finalize*`, or `sync*`, treat that callback as a critical part of the state contract.

### Warning Signs

- Logs show local values already dropped to zero, but outer/shared values remain stale.
- Visible collapse finishes, but click region, reservation, or service flag remains active.
- Runtime warnings appear near the same phase transition where cleanup should complete.
- Repeated fixes to hit-testing or wrapper sizing change symptoms but do not clear the stale outer state.

## E. Universal Verification Strategy

### Agnostic Testing Logic

1. Log three layers separately:
   - local visual/reset value,
   - callback/finalizer entry and exit,
   - outer shared/service value.
2. Reproduce the failing transition and confirm whether the finalizer runs to completion.
3. After fixing the interruption, verify the outer/shared value now changes without extra geometry hacks.
4. Re-run the same transition twice to ensure re-entry does not keep stale state.
5. Run the full shell load check: `timeout 5 qs --path .`.

## References

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/SuperIslandStateMachineTransientPolicy.qml`
- `modules/bar/superisland/SuperIslandStateMachineTimelineCallbacks.js`
- `services/BarLayoutService.qml`
- `modules/bar/BarWindow.qml`
