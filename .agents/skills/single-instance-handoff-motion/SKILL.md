---
name: single-instance-handoff-motion
description: Use when one visual element appears to move between hosts or states and the handoff causes teleporting, duplicate instances, premature fade-out, or exit-phase reappearance of related UI.
---

# Single-Instance Handoff Motion

Stabilize handoff motion by treating moving geometry, steady-state targets, and exit visibility gates as one coordinated flow.

## A. Core Concept & Standard Workflow

### Initialization/Setup Checklist

1. Identify whether the bug belongs to clock geometry, title visibility, or handoff timing.
2. Name the visible owners explicitly:
   - bar host clock source
   - detached workspace clock target
   - title capsule host card
3. Verify whether the current implementation uses one clock instance or a visibility swap between two instances.
4. Export detached target geometry before tuning motion.
5. Gate title-card rendering by visible hint phase, not by broad lifecycle state alone.
6. Verify the moving clock stays alive until the host truly returns to idle.

### Key APIs / Core Configurations

| Area | Files / Symbols | Purpose |
| --- | --- | --- |
| Shared moving clock | `modules/bar/widgets/SuperIslandWidget.qml` `_barExpandedSharedClockVisible`, `_barExpandedSharedClockY`, shared `IslandIdleClockCard` | Owns the single visible clock instance during bar-expanded hint handoff. |
| Detached clock target geometry | `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml` `_clockRow`, `relocatedClockRowY` | Exports the lower workspace clock slot without rendering a second steady-state clock. |
| Detached target propagation | `modules/bar/superisland/IslandWindowHintCard.qml` `relocatedClockRowY`, `relocatedClockCenterY` | Bridges detached target geometry up to the host widget. |
| Live detached hint bridge | `modules/bar/superisland/SuperIslandAttachedContentDeck.qml` `hintCardLoaderItem`, `sharedClockActive` | Exposes the live detached hint card and carries shared-clock state into it. |
| Main title card routing | `modules/bar/widgets/SuperIslandWidget.qml` `_componentForEvent()`, `_barExpandedMainCardVisible`, `_barExpandedWindowHintTailActive` | Decides whether the title capsule card may be instantiated during hint / exit / tail phases. |
| Hint lifecycle | `modules/bar/superisland/SuperIslandStateMachineTransientPolicy.qml` `startBarExpandedWindowHint()`, `finishWindowHint()`, `completeWindowHintExit()` | Defines the phase changes that the clock/title gates must respect. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| Bar-expanded `window-hint` clock | The clock appeared to teleport into the detached workspace, then duplicate, fade too early, and let title capsules reappear during exit because motion ownership, target geometry, and visibility gating were split incorrectly. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Render two full visual instances and hope opacity or timing swaps hide the seam, while target geometry and exit gates live in different places. |
| ✅ The Best Practice (The Fix) | Keep one visible instance whenever possible, export target geometry explicitly, and gate all competing render paths at the routing layer. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- Prefer one visual instance for the whole handoff.
- If a second structure must exist, make it geometry-only rather than a second steady-state visual owner.
- Export landing targets explicitly before tuning motion.
- If an element must cross a clipped host, move the visual owner to a non-clipped parent.
- Gate competing cards or loaders at component selection time, not only with opacity.
- Keep the moving instance alive until the lifecycle truly returns to idle.

### Warning Signs

- Hiding the whole main loader when you only meant to hide the clock, which also hides title capsules.
- Forgetting that replace/outgoing/incoming layers can instantiate the same card family as the main loader.
- Using `attachedPanelVisibleHeight > 0` as the shared-clock lifetime gate, which makes the moving clock disappear too early.
- Leaving `Behavior on opacity` on the moving handoff clock, which creates a visible fade-gap even after geometry is correct.
- Treating detached steady-state content as presentation, not as geometry export, which reintroduces duplicate-instance handoff artifacts.

## E. Universal Verification Strategy

### Agnostic Testing Logic

1. Verify there is exactly one visible clock throughout open, hold, and close.
2. Verify the moving clock can cross the host seam without being clipped.
3. Verify the detached panel exports a target position even when it no longer renders its own steady-state clock.
4. Verify title capsules are visible only during the intended display phase and cannot reappear through replace/outgoing/incoming layers.
5. Verify the moving clock remains alive until the owner returns to idle, not merely until the detached panel height reaches zero.
6. Run the full shell load check: `timeout 5 qs --path .`.

## References

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`
- `modules/bar/superisland/SuperIslandAttachedContentDeck.qml`
- `modules/bar/superisland/SuperIslandStateMachineTransientPolicy.qml`
