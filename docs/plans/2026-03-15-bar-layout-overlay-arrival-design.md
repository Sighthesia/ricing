# Bar Layout Overlay Arrival Actor Design

**Date:** 2026-03-15
**Status:** Approved
**Parent docs:**
- `docs/plans/2026-03-15-bar-layout-dual-layer-geometry-design.md`
- `docs/plans/2026-03-15-bar-layout-slot-driven-arrival-design.md`
- `docs/plans/2026-03-14-bar-layout-geometry-refactor-design.md`

## Overview

The dual-layer geometry work fixed section frames, and the slot-driven arrival investigation proved the remaining insertion bug is not a width problem.
The real issue is that a newly inserted delegate can become visible before Qt's internal positioner timing has moved it to its final slot.

Several attempts to gate the real delegate still left visibility behavior partly controlled by Qt internals.
That means the first visible frame should no longer depend on the real delegate at all.

The fix is to make `DragOverlay` temporarily own the first visible arrival frame.
The overlay renders a one-shot arrival actor at the service-owned slot, then hands off to the real delegate only after the arrival actor is complete.

## Problem To Solve

- The first visible frame of a newly inserted widget must be in the correct service-owned slot.
- The visible arrival path must not depend on `Row.add` timing or `Repeater` delegate layout races.
- The real delegate must not flash at `x: 0` while the overlay actor is active.
- The design must stay compatible with hot-reload and teardown cleanup rules already established for drag and width state.

## Decision

Adopt an overlay-driven arrival actor with service-owned handoff state.

That means:

- `BarLayoutService` publishes a one-shot arrival actor snapshot keyed by `instanceKey`
- `DragOverlay` renders the arrival actor from that snapshot at the target slot
- the real `BarWidgetWrapper` stays hidden while the arrival actor is active
- once the overlay actor completes, the service clears the actor and allows the real delegate to reveal

This is like sending a stand-in onto the stage to hit the exact mark first, then letting the real performer take over only after the audience's eye is already anchored to the correct place.

## Considered Approaches

### Recommended: Overlay arrival actor

Keep the real delegate out of the first visible frame and let the overlay own that moment.

Pros:

- takes the user-visible first frame away from Qt positioner timing
- keeps all slot placement sourced from `BarLayoutService`
- aligns naturally with the existing `DragOverlay` responsibility for temporary geometry-driven visuals
- contains the complexity inside an explicitly transient path

Cons:

- adds another short-lived runtime visual state
- requires a clean handoff rule between overlay actor and real delegate

### Alternative: Cross-fade overlay and delegate together

Show both the overlay actor and the real delegate briefly, fading one out while fading the other in.

Pros:

- smoother visual continuity

Cons:

- higher risk of double-image artifacts
- more synchronization complexity than needed for the bug

### Rejected: Continue delegate-first reveal gating

Keep trying to delay or redirect the real delegate's reveal until Qt layout happens to settle.

Pros:

- no new overlay behavior

Cons:

- still depends on internal timing outside our control
- already showed nondeterministic results in this branch
- fights the framework instead of isolating it

## Architecture

### 1. Service-owned arrival actor snapshot

`BarLayoutService` remains the single source of truth for all runtime geometry, so the overlay actor must be service-driven.

Add a one-shot arrival actor snapshot keyed by `instanceKey`.
It can either extend the current arrival snapshot or replace it with a richer structure, but it must remain transient runtime state only.

Each snapshot should include at least:

- `instanceKey`
- `widgetId`
- `section`
- `barLeft`
- `barWidth`
- `barCenterX`
- `active`
- handoff phase such as `"overlay" | "delegate"`

The snapshot is created only after slot geometry has been recomputed, so the actor always lands on a real service-owned slot.

### 2. `DragOverlay` becomes the first visible arrival layer

`DragOverlay` already renders temporary, service-owned visuals in bar coordinates.
That makes it the right place to render a one-shot arrival actor.

The arrival actor should:

- use the same widget source registry as the drag overlay floating copy
- position itself directly from `barLeft` and `barWidth`
- keep the visual deliberately minimal: enough to show the widget in its correct slot without inventing a second design language

This keeps arrival, drag copy, and drop-zone visuals in one dedicated transient rendering layer.

### 3. Real delegate stays hidden during overlay phase

`BarWidgetWrapper` should stop trying to own the first visible arrival frame.
Instead, it only needs a simple question:

- "Is there still an active overlay arrival actor for my `instanceKey`?"

If yes:

- keep real delegate hidden
- continue reporting measured width normally

If no:

- run the normal enter animation

This makes the real delegate's reveal depend on explicit service state, not on positioner timing.

### 4. Handoff contract

The handoff should be explicit and one-shot.

Recommended sequence:

1. service creates arrival actor snapshot after `addWidget()` recomputes slots
2. overlay actor renders immediately at final slot geometry
3. overlay actor runs a short, existing-style enter motion or immediate settle
4. overlay actor completion flips the snapshot into delegate-ready state or clears it entirely
5. real delegate sees no active overlay actor and runs its normal reveal

No long-lived overlap is needed.
The overlay owns the first visible frame; the delegate owns steady state.

### 5. Cleanup and stale-state rules

Arrival actor state is as transient as drag state and must be cleaned just as aggressively.

It must be cleared when:

- the actor hands off successfully
- the instance is removed
- layout resets or model replacement happens
- hot reload removes or recreates the instance

Service reconciliation should remove any actor snapshot whose `instanceKey` no longer exists in `layoutModel`.

## Data Flow

1. `addWidget()` appends a new layout item with a stable `instanceKey`.
2. `BarLayoutService` recomputes slots and records an overlay-arrival snapshot for that instance.
3. `DragOverlay` renders a one-shot actor directly at the service-owned slot.
4. The real `BarWidgetWrapper` stays hidden while the actor is active.
5. The actor completes and the service clears or advances the snapshot.
6. The real delegate reveals only after the overlay-owned first frame is done.

## Error Handling And Fallbacks

- If no arrival snapshot exists, the overlay renders nothing and the delegate follows the normal path.
- If an actor snapshot survives unexpectedly, service cleanup removes it once the instance disappears from the model.
- If the overlay actor fails to load a widget source, clear the snapshot and fall back to the real delegate rather than leaving the widget permanently hidden.
- Any fallback should prefer a brief normal reveal over a stuck hidden widget.

## Testing Strategy


Required coverage:

- service exposes arrival actor state for a newly inserted widget
- while actor state is active, the real delegate remains hidden
- `DragOverlay` exposes an arrival actor item at the expected slot geometry
- after handoff, the overlay actor disappears and the real delegate becomes visible
- the visible handoff sequence does not overlap the previously placed left widget
- actor state is cleared during teardown/reset paths

Then run:

- `timeout 10 qs --path .`

## Affected Files

- `services/BarLayoutService.qml`
- `modules/bar/DragOverlay.qml`
- `modules/bar/BarWidgetWrapper.qml`
- `modules/bar/BarSection.qml` only if transition experiments need cleanup

## Non-Goals

- rewriting the bar to fully absolute positioning
- changing drag overlay behavior unrelated to arrival
- introducing a permanent second rendering path for normal widget state
- changing persistence schema beyond transient runtime overlay state
