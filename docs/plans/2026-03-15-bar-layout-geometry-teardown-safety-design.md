# Bar Layout Geometry Teardown Safety Design

**Date:** 2026-03-15
**Status:** Approved
**Parent docs:**
- `docs/plans/2026-03-14-bar-layout-geometry-refactor-design.md`
- `docs/plans/2026-03-14-bar-layout-geometry-refactor-plan.md`

## Overview

Task 1-6 moved bar geometry toward a single service-owned model, but teardown paths still need an explicit contract.
The failure mode is simple: a width measurement or drag reference can outlive the widget instance that produced it.
When that happens during widget removal or hot reload, the next geometry recompute can briefly use stale data and make the bar jump.

This task keeps `BarLayoutService` as the only geometry source of truth while adding a deliberate cleanup handshake.
`BarWidgetWrapper` reports measurement lifecycle changes immediately, and `BarLayoutService` performs final reconciliation against the active layout model.

## Problem To Solve

- A widget delegate can be destroyed before or after the matching `layoutModel` entry changes.
- A removed widget can leave behind a cached measured width unless the service reconciles state.
- An active drag session can keep pointing at a deleted instance unless drag state is cleared centrally.
- Hot reload can replay these events in a different order than normal startup.

The business effect is visible instability: insertion targets, picker anchors, or drag ghosts can derive from a widget that no longer exists.

## Considered Approaches

### Recommended: Dual-guard cleanup

Use a two-part contract:

- `BarWidgetWrapper` eagerly clears the last width it reported when its delegate is destroyed or its `instanceKey` changes.
- `BarLayoutService` reconciles all geometry-facing caches against the current `layoutModel` whenever geometry is recomputed.

This is like a warehouse with barcode scans at the door and a nightly inventory check.
The door scan keeps things responsive, and the inventory check guarantees the ledger is still correct even if an event arrived out of order.

Pros:

- safe under normal removal and hot reload ordering differences
- keeps geometry ownership centralized in the service
- avoids stale drag ghosts and stale slot widths without adding more UI-local state

Cons:

- cleanup logic exists in two layers on purpose
- requires tests that distinguish delegate teardown from model removal

### Alternative: Service-only reconciliation

Only `BarLayoutService` clears stale state.
This keeps ownership pure, but it delays cleanup until the next recompute and makes teardown behavior depend more heavily on lifecycle ordering.

### Alternative: Wrapper-only cleanup

Only `BarWidgetWrapper` clears widths during destruction and key changes.
This is lightweight, but it is too fragile for hot reload because the service would have no final check against the current model.

## Architecture

### 1. Ownership split

`BarWidgetWrapper` owns measurement reporting, not geometry truth.
It may say "my current width is X" or "the last key I reported is gone," but it does not decide whether a slot, section, or drag target remains valid.

`BarLayoutService` remains the canonical owner of:

- measured-width cache
- section geometry
- slot geometry
- picker anchors
- drag snapshot

### 2. Reconciliation in `BarLayoutService`

The service derives the active instance-key set from `layoutModel` and removes any geometry-facing cache entries that no longer belong to a live model item.

That reconciliation must at minimum:

- drop stale `_widgetMeasuredWidths` entries
- rebuild section and slot geometry only from active model items
- clear the active drag snapshot if `draggedInstanceKey` is no longer present

This keeps all downstream consumers deterministic because `BarContent`, `BarSection`, `DropZone`, and `DragOverlay` only read service-owned geometry.

### 3. Destroy and remove semantics

There are two different teardown cases and they should behave differently.

Delegate destroyed, model entry still present:

- clear the last reported measured width
- keep the logical slot alive through the service fallback width until a replacement delegate reports again

Model entry removed or replaced:

- remove stale measured-width cache entries
- remove stale slot output by recomputing from the new model
- clear drag state if it references the removed instance

That distinction avoids visual collapse during transient reloads while still preventing stale data from surviving true removal.

### 4. Hot-reload safety

Hot reload is safe no matter which event happens first:

- delegate destruction before model mutation
- model mutation before delegate destruction
- drag session interrupted by either of the above

The wrapper gives an immediate hint, and the service performs the final truth check.
No module under `modules/bar/` should add its own persistent geometry cache to compensate.

## Testing Strategy


Required coverage:

- delegate destruction clears the reported measured width for that `instanceKey`
- `removeWidget()` removes stale width and slot data for the removed instance
- removing the active drag instance clears `dragSnapshot`
- hot-reload-style model replacement such as `resetLayout()` or `applyJson()` leaves no stale geometry cache behind

Verification order:

6. `timeout 10 qs --path .`

## Affected Files

- `services/BarLayoutService.qml`
- `modules/bar/BarWidgetWrapper.qml`
