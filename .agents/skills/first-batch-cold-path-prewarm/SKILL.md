---
name: first-batch-cold-path-prewarm
description: Use when a search, picker, launcher, clipboard, or results list only stutters on the first large match/open, then becomes smooth on subsequent runs. Applies when the dominant cost is cold delegate/icon/text/layout initialization rather than steady-state filtering or GPU work. Fix by prewarming a small representative first batch without changing search semantics or list structure.
---

# First-Batch Cold-Path Prewarm

Use this when the user-visible symptom is:

- the **first** large search/result reveal stutters
- repeating the same large match again is much smoother
- the effect is **one-time** or strongly front-loaded
- continuous performance after the first run is acceptable

This pattern is different from steady-state per-frame jank. Do not jump to list-architecture rewrites or animation tuning if the evidence says the problem is mostly cold initialization.

## Trigger Signs

- First hit of a broad query such as `a`, `s`, or `>clip` stalls once, but backspacing and re-entering does not.
- Removing blur/shader work helps only partly, but the biggest improvement comes from doing the expensive first reveal once ahead of time.
- The list may already be on a reasonable `P0+P1` baseline: debounced query, light transitions, and no heavy blur effects.
- The work that is likely cold includes:
  - delegate instantiation
  - `IconImage` icon resolution/loading
  - `Text`/`FluidText` font shaping and first measurement
  - first row/tile layout construction

## Non-Goals

- Do **not** change search matching logic.
- Do **not** change result ordering semantics.
- Do **not** rewrite the list model structure unless evidence shows the cold-path hypothesis is wrong.
- Do **not** restore heavy per-item blur/mask effects just to hide the symptom.

## Preferred Fix Shape

### 1. Prewarm a small representative batch

Instantiate a hidden batch of the first few representative delegates **before** the user triggers the heavy first match.

Typical batch sizes:

- app grids/lists: `8-16`
- clipboard rows: `12-24`
- compact mixed result lists: `12-20`

The hidden prewarm should be:

- offscreen or invisible
- non-interactive
- structurally similar to the real delegate subtree
- started after open / on idle / after data arrives

### 2. Prewarm only the expensive subtree

You often do **not** need the full real delegate. A hidden prewarm item can include only the cold pieces:

- icon image
- primary and secondary text
- representative row/tile layout containers

This keeps the change small and avoids interfering with selection, hover, and navigation logic.

### 3. Keep the real list logic unchanged

The real list should continue to use the existing search semantics and transitions. The prewarm layer is only there to front-load cold creation cost.

## Decision Rule

Choose this skill before deeper structural changes when all are true:

1. the stall is strongly **first-time only**
2. subsequent large matches are significantly smoother
3. the current structure is otherwise acceptable
4. the user asked for a **narrow fix** or wants to preserve current behavior

If the list remains bad on every large query even after one warm run, this skill is the wrong primary fix. Use model/transition architecture work instead.

## Implementation Pattern

### Hidden prewarm container

Use an invisible item placed far offscreen:

```qml
Item {
    visible: false
    opacity: 0
    x: -10000
    y: -10000

    Repeater {
        model: prewarmArmed ? prewarmItems : []
        delegate: Item {
            // Only the expensive representative subtree
        }
    }
}
```

### Idle/arrival trigger

Use a `Timer { interval: 0 }` or a data-arrival hook:

```qml
Timer {
    id: prewarmTimer
    interval: 0
    repeat: false
    onTriggered: root.prewarmArmed = true
}
```

Good activation moments:

- `Component.onCompleted`
- after the data source becomes non-empty
- after the surface opens but before the user is likely to type

## Validation

Confirm these specifically:

- The **first** broad search is smoother than before.
- The **second** broad search is not worse.
- Search results, ordering, and keyboard behavior are unchanged.
- No new QML warnings/errors are introduced.
- The hidden prewarm subtree does not affect visible layout or input.

## Anti-Patterns

- Prewarming the **entire** dataset when only a representative first batch is needed.
- Prewarming by restoring the old visible list structure or hidden-item animation path.
- Mixing this with large structural rewrites in the same pass unless the cold-path hypothesis has already failed.
- Treating a first-time-only stall as a generic GPU problem without checking cold delegate/icon/text costs.

## Afloat Case Note

In afloat, this pattern was effective after reverting an overreaching `P2` structural rewrite. The stable baseline was:

- debounced independent launcher/clipboard query paths
- no per-item `MultiEffect` blur
- existing list semantics preserved

The successful narrow fix was to prewarm a small hidden batch for:

- independent `AppGrid`
- independent `ClipboardList`
- island full-screen app list
- island full-screen clipboard list
- compact mixed results list

That pulled `AppGridDelegate`, `ClipboardDelegate`, `IconImage`, `FluidText`, and representative row/tile layout cold costs forward so the first large match no longer paid them all at once.
