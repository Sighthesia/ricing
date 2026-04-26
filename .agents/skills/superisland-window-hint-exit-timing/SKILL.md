---
name: superisland-window-hint-exit-timing
description: Use when SuperIsland window-hint exit timing looks split across the title host and detached workspace body, especially if one background retreats first, width targets seem ignored, or fixing exit timing breaks throw/catch alignment.
---

# SuperIsland Window-Hint Exit Timing

Keep window-hint exit timing fixes scoped to the real width owner instead of changing shared throw/catch or attached-panel height state.

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

## B. The Specific Symptom / Goal (The Trigger)

- **Context**: `window hint` in bar-expanded mode showed the detached workspace background retreating before the upper title background. Early attempts that changed `_pillExpanded` made exit timing look closer but broke throw/catch Y alignment and created a visible seam between title and workspace regions.

## C. Project-Specific Implementation (Targeted)

### The Fix

| File | Change |
| --- | --- |
| `modules/bar/widgets/SuperIslandWidget.qml` | Keep `_pillExpanded` untouched so shared catch/height motion stays on the original track. |
| `modules/bar/widgets/SuperIslandWidget.qml` | Add `_barExpandedExitBaseWidth` to preserve the pre-expanded bar width until hint exit completes. |
| `modules/bar/widgets/SuperIslandWidget.qml` | During `root._phase === "hint-exit"`, drive upper-host `_expandedWidth` toward `_barExpandedExitBaseWidth` instead of `root._collapsedWidth`, because `root._collapsedWidth` can be polluted by `_attachedCollapseBaseWidth`. |
| `modules/bar/widgets/SuperIslandWidget.qml` | Record both `_barExpandedEntryBaseWidth` and `_barExpandedExitBaseWidth` when bar-expanded hint activates, and clear them only when the mode ends. |

### Minimal Relevant Snippet

```qml
property real _barExpandedExitBaseWidth: 0

readonly property real _expandedWidth:
    root._barExpandedHintActive
        ? (root._phase === "hint-exit"
            ? Math.max(
                root._barExpandedExitBaseWidth > 0
                    ? root._barExpandedExitBaseWidth
                    : root._idleCollapsedWidthLive,
                root._idleCollapsedWidthLive
            )
            : root._barExpandedMainHintWidth)
        : ...
```

## D. Generalizable Principles (Highly Portable)

### Root Cause Mechanism

- The upper title host and lower workspace body do not share one geometry owner.
- The lower body exits through attached collapse state, while the upper host exits through bar width ownership.
- A seemingly reasonable "collapsed width" can be semantically wrong if it is reused from a lower-panel collapse cache.
- Changing a shared `expanded` flag fixes timing indirectly by altering a larger motion graph, which often breaks unrelated Y motion or shell continuity.

### Agnostic Rules

- If two visible regions exit together but belong to different hosts, synchronize their targets before synchronizing their state machines.
- Do not change a global expand/collapse flag when the bug is only about one host's width target.
- Separate "upper host return width" from "lower panel collapse width" even if both look like a collapsed state.
- Preserve pre-transition geometry snapshots when exit must return to the entry footprint rather than to a live recomputed width.

### Common Pitfalls

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
