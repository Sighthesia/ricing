# Bar Layout Slot-Driven Arrival Design

**Date:** 2026-03-15
**Status:** Approved
**Parent docs:**
- `docs/plans/2026-03-15-bar-layout-dual-layer-geometry-design.md`
- `docs/plans/2026-03-15-bar-layout-dual-layer-geometry-plan.md`
- `docs/plans/2026-03-14-bar-layout-geometry-refactor-design.md`

## Overview

The dual-layer geometry refactor fixed section frames and content bands, but it did not solve one remaining layout-mode arrival bug.
When a widget is inserted into the left docking region, the new delegate can become visible before the `Row` positioner has moved it to its final slot.
The result is a brief overlap where the widget appears at the docking origin instead of its eventual slot.

The key lesson from the failed transition-only experiments is that this is not a width problem.
By the time the new widget becomes visible, its width is already correct, but its `x` position is still stale.
That means the fix must stop relying on `Row.add` timing and instead make arrival visibility obey service-owned slot geometry.

## Problem To Solve

- New layout-mode arrivals should not become visible before their actual position matches the slot derived by `BarLayoutService`.
- The fix must not depend on fragile `Row.add` or `ViewTransition` timing assumptions.
- Drag-time reorder behavior should stay on the existing drag snapshot path.
- The solution must remain compatible with teardown and hot-reload cleanup added in Task 7.

## Decision

Adopt a service-owned, one-shot arrival snapshot keyed by widget `instanceKey`.

That means:

- `BarLayoutService` publishes the target slot geometry for a newly added widget
- `BarWidgetWrapper` checks its real bar-space geometry against that slot before it starts the enter animation
- the first visible frame of the new widget is already aligned with the service-owned slot
- the arrival snapshot is then consumed and cleared

This is like handing a car its exact parking slot before opening the garage door.
The car is not shown to the audience until it is actually in the correct bay.

## Considered Approaches

### Recommended: Service-owned slot arrival gate

Use a one-shot arrival snapshot that stores the new widget's target slot in bar coordinates.
The delegate remains visually hidden until its real mapped position matches that slot.

Pros:

- keeps geometry truth in `BarLayoutService`
- avoids fighting Qt positioner internals directly
- solves the overlap at the moment the widget first becomes visible
- keeps the fix scoped to layout-mode service-driven insertion

Cons:

- adds one more transient service-owned geometry state
- needs careful cleanup so stale arrival snapshots do not survive teardown or model replacement

### Alternative: Overlay-based temporary arrival actor

Render a temporary overlay copy of the new widget from service slot geometry, then fade in the normal delegate later.

Pros:

- exact visual control

Cons:

- duplicates rendering paths
- increases complexity and synchronization cost
- overbuilt for a single arrival symptom

### Rejected: Keep patching `Row.add` timing

Continue modifying `BarSection` transitions and `BarWidgetWrapper` width behavior until Qt happens to line up with the desired first frame.

Pros:

- smaller diff on paper

Cons:

- still depends on Qt timing rather than our geometry model
- already failed to produce deterministic behavior in this branch
- too brittle for future hot reload and layout changes

## Architecture

### 1. Arrival snapshot ownership in `BarLayoutService`

`BarLayoutService` remains the only source of truth for runtime geometry, so the arrival handshake also belongs there.

Add a small one-shot arrival snapshot keyed by `instanceKey`.
Initial scope is layout-mode service-driven insertion through `addWidget()`.
Drag reorder continues to use the existing drag snapshot and is not changed by this task.

Each arrival snapshot should include at least:

- `instanceKey`
- `section`
- `barLeft`
- `barWidth`
- `barRight`
- `active`

The snapshot should be created only after the service has recomputed slot geometry, so it always reflects the final target slot for the new instance.

### 2. Bar-space comparison instead of local timing

The wrapper should not guess when a `Row` has settled.
Instead, it should compare its real mapped position in bar coordinates to the service slot snapshot.

That comparison should use existing item mapping:

- locate `BarContent`
- compute `wrapper.mapToItem(barContent, 0, 0).x`
- compare that `barLeft` to the service arrival snapshot `barLeft`

This avoids any need for the service to know `Row` spacing internals.
The service stays responsible for the slot, and the wrapper simply asks, "Am I actually there yet?"

### 3. Wrapper reveal gate in `BarWidgetWrapper`

`BarWidgetWrapper` already owns enter animation timing, so it should own the final reveal gate too.

If the wrapper has an active arrival snapshot:

- keep opacity at 0
- do not start the enter animation yet
- retry when geometry-affecting values change such as `x`, width, or natural width

When the wrapper's actual bar-space left and width are sufficiently close to the arrival slot:

- clear the arrival snapshot through the service
- start the normal enter animation

This preserves the current enter motion style while making the first visible frame correct.

### 4. Cleanup and stale-state rules

Arrival snapshots are transient and must be treated like other runtime geometry caches.

They must be cleared when:

- the snapshot is consumed by the matching wrapper
- the instance is removed
- layout is reset or replaced
- hot reload removes or replaces the target instance

This cleanup should reuse the same principle as Task 7: the service reconciles state against the live layout model.

### 5. Scope boundary

Initial scope is intentionally narrow.

Included:

- `addWidget()` while layout mode is active
- first visible arrival of the inserted delegate

Not included yet:

- drag-end reorder animation
- overlay-based arrival copies
- a general-purpose visibility scheduler for every widget state change

That keeps the solution aligned with the bug that was actually reproduced.

## Data Flow

1. `addWidget()` appends a new layout item with a stable `instanceKey`.
2. `BarLayoutService` recomputes slot geometry and records a one-shot arrival snapshot for the new instance.
3. `BarWidgetWrapper` reads that snapshot on creation.
4. The wrapper compares its real bar-space geometry to the service slot.
5. Once they match within tolerance, the wrapper clears the arrival snapshot and runs the existing enter animation.
6. The first visible frame is already in the correct slot, so no overlap is shown.

## Error Handling And Fallbacks

- If an arrival snapshot is missing, the wrapper falls back to the current normal enter path.
- If a snapshot exists but the instance disappears, service reconciliation must remove it.
- Any such fallback must be documented and remain service-owned, not a local UI guess.

## Testing Strategy


Required coverage:

- service exposes a per-instance arrival geometry helper or state
- a newly added left-section widget has an active arrival snapshot before reveal
- the wrapper stays hidden until its real bar-space geometry matches the target slot
- the first visible frame of the new widget does not overlap the previous widget
- arrival snapshots are cleared after use and during teardown/reset paths

Then run:

- `timeout 10 qs --path .`

## Affected Files

- `services/BarLayoutService.qml`
- `modules/bar/BarWidgetWrapper.qml`
- `modules/bar/BarSection.qml`

## Non-Goals

- replacing the `Row` positioner entirely
- reworking drag overlay behavior
- introducing a second rendering path for normal widget display
- changing persistence schema beyond transient runtime geometry state
