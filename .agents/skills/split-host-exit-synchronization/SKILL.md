---
name: split-host-exit-synchronization
description: Use when two visible regions must exit together but belong to different geometry owners, especially if one region retreats early or fixing timing by changing global state breaks unrelated motion.
---

# Split-Host Exit Synchronization

Keep exit timing fixes scoped to the real geometry owner instead of changing unrelated shared motion state.

## A. Core Concept & Standard Workflow

### Initialization/Setup Checklist

1. Identify the visible owners of the upper title host and lower detached workspace body.
2. Trace which property owns upper-host width, lower-panel width, lower-panel height, and throw/catch Y offset.
3. Confirm whether the bug is caused by `expanded` state, width targets, or attached collapse state.
4. Only then change the smallest owner that can synchronize exit timing.

### Key APIs / Core Configurations

| Area | Files / Symbols | Purpose |
| --- | --- | --- |
| Upper host width | `modules/bar/widgets/SuperIslandWidget.qml` `_expandedWidth`, `_pillTransitionControl`, `_pillBg` | Owns the visible title-host retreat in bar-expanded hint mode. |
| Lower host collapse | `modules/bar/widgets/SuperIslandWidget.qml` `_attachedPanelRevealWidth`, `_attachedPanelRevealHeight`, `_attachedPanelVisibleHeight` | Owns detached workspace body collapse timing. |
| Attached motion | `modules/bar/superisland/SuperIslandTimelineAttached.qml`, `modules/bar/superisland/SuperIslandStateMachineOverlayPolicy.qml` | Owns throw/catch, reveal, and collapse timelines. |
| Exit trigger | `modules/bar/superisland/SuperIslandStateMachineTransientPolicy.qml` `finishWindowHint()` | Enters `hint-exit` and starts attached collapse. |
| Width retarget behavior | `modules/bar/BarExpandTransition.qml` `onExpandedWidthChanged`, `_handleTargetChange()` | Lets width retarget while `expanded` stays true. |

## B. The Specific Trap / Symptom (The Trigger)

| Context | Summary |
| --- | --- |
| Bar-expanded `window-hint` exit | The upper title host and lower workspace body exited on different beats because they had different geometry owners. Early fixes changed a shared expanded flag, which improved timing superficially but broke unrelated Y motion. |

## C. The Anti-Pattern vs. Best Practice

| Pattern | Explanation |
| --- | --- |
| ❌ The Anti-Pattern (Why it failed) | Fix a host-specific retreat problem by toggling a global expanded/collapsed state that also controls unrelated motion branches. |
| ✅ The Best Practice (The Fix) | Identify each host's true width/height owner, preserve any needed pre-transition snapshot, and retarget only the host that is visibly late. |

## D. Generalizable Rules (Highly Portable)

### Agnostic Rules

- If two regions look like one transition but use different owners, synchronize targets before changing shared state machines.
- Keep host-return geometry separate from attached-collapse geometry even if both resemble a collapsed state.
- Preserve entry snapshots when exit must return to the entry footprint rather than a live recomputed width.
- Avoid global state edits when the bug is one host's width target.

### Warning Signs

- Treating `expanded = false` as the only way to trigger width retreat.
- Reusing a lower-panel collapse cache for an upper-host width return.
- Clearing the entry-width snapshot too early, then wondering why exit falls back to the wrong runtime width.
- Fixing exit timing with opacity while geometry still retreats in a later phase.

## E. Universal Verification Strategy

### Agnostic Testing Logic

1. Verify the upper host starts shrinking on the same user-visible exit beat as the lower body.
2. Verify throw/catch Y alignment does not change after the fix.
3. Verify the fix works after the hint has fully settled, not only during immediate open-close.
4. Compare the exit width target against the preserved entry footprint rather than a live collapse cache.
5. Run the full shell load check: `timeout 5 qs --path .`.

## References

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/SuperIslandStateMachineTransientPolicy.qml`
- `modules/bar/superisland/SuperIslandStateMachineOverlayPolicy.qml`
- `modules/bar/superisland/SuperIslandTimelineAttached.qml`
- `modules/bar/BarExpandTransition.qml`
