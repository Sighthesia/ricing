# Bar Layout Geometry Refactor Design

**Date:** 2026-03-14
**Status:** Approved

## Overview

The current bar layout logic mixes several incompatible geometry models.
`BarLayoutService` stores logical order, `BarSection` derives insertion positions from live `Row` children, `BarContent` and `DropZone` still divide the bar into equal thirds, and `BarWidgetWrapper` drives drag visuals from its own measured width.
This works when widget widths are static, but it breaks once widgets resize during layout mode or when section content no longer matches equal-width regions.

This refactor upgrades `BarLayoutService` into the single source of truth for bar geometry.
The service will keep layout persistence, but it will also derive section boundaries, widget slot positions, insertion targets, picker anchors, and drag ghost geometry from one consistent model.
Rendering code in `modules/bar/` will consume that shared geometry instead of re-measuring siblings ad hoc.

## Problems To Solve

- Insertion indicators drift because `BarSection.insertIndexAt()` reads transient `Row` child positions.
- Dragged widgets can jump when width changes because visual drag position, ghost width, and row reflow are computed from different moments in time.
- Section hit testing still uses equal thirds even though visible content is content-adaptive.
- Layout mode overlays do not align with real widget baselines, so zone borders and edge widgets can visually fight each other.
- Picker placement is tied to synthetic thirds instead of true section geometry.

## Decision

Adopt a single geometry model owned by `BarLayoutService`, with center-region behavior set to visual-centering priority.

That means:

- the center section tries to remain visually centered in the bar
- when left or right content expands, the center section first loses available interaction width before it visually shifts
- slot order stays stable during width changes
- every drag/drop and overlay decision is derived from the same section and slot boundaries

## Considered Approaches

### Recommended: Service-owned geometry model

Treat `BarLayoutService` like a seating chart for the bar.
The service owns the official map, and every renderer asks that map where widgets, gaps, targets, and anchors belong.

Pros:
- fixes the current bugs at the architectural root
- keeps drag hit testing, insertion indicators, and picker anchoring consistent
- makes width-change behavior deterministic instead of timing-sensitive
- creates a clean place to extend future layout features

Cons:
- requires a real refactor across several bar modules
- needs a measurement handshake between rendered widgets and the service

### Rejected: Continue patching `Row` behavior

Pros:
- smaller immediate diff

Cons:
- preserves multiple geometry truths
- likely causes more edge regressions when widget widths change again
- keeps picker and drop-zone logic disconnected from real layout

### Rejected: Full absolute-position layout rewrite

Pros:
- maximum control over exact placement

Cons:
- too invasive for current needs
- higher regression risk across animation and loading behavior
- throws away useful parts of the current section/delegate structure

## Architecture

### 1. Geometry ownership in `BarLayoutService`

`BarLayoutService` remains the persistent owner of logical widget order, but it also becomes the runtime owner of derived geometry.

The service will track:

- bar content width and padding inputs
- per-widget measured width keyed by stable widget instance key
- per-section derived boundaries
- per-section ordered slot geometry
- active drag snapshot geometry
- picker anchor positions per section

The key shift is that geometry becomes derived state, not something each visual component recomputes privately.

### 2. Stable slot model

Each rendered widget instance gets a stable instance key, and that key is used for both persistence-facing lookup and runtime geometry measurement.

For every section, the service derives a slot list like:

- instance key
- widget id
- order
- measured width
- slot start x
- slot center x
- slot end x

Insertion targets are then computed from slot boundaries, not live child positions.
When a widget is dragged, the service computes ghost insertion from the same slot list after excluding the dragged instance.

### 3. Content-adaptive section boundaries

The bar no longer uses equal thirds for layout interactions.
Instead, the service derives three section regions from actual content and bar constraints:

- left region grows from left padding inward
- right region grows from right padding inward
- center region is visually centered around bar midpoint

When content expands:

- left and right regions expand based on measured slot widths
- center keeps its visual midpoint first
- the center interaction region shrinks before its anchor shifts
- when overlap becomes unavoidable, boundary resolution pushes section limits outward in a stable order-preserving way

This is like keeping the main performer centered on stage, but narrowing the walkway around them before moving the act itself.

### 4. Rendering becomes geometry consumers

`modules/bar/` components stop guessing layout and instead read service-owned geometry.

- `BarContent.qml` asks the service for section regions and picker anchors
- `BarSection.qml` renders widgets in logical order but uses shared slot geometry for insertion indicators and local hit tests
- `DropZone.qml` paints and reacts from real section boundaries instead of thirds
- `DragOverlay.qml` renders drag highlights and floating copies from service geometry
- `BarWidgetWrapper.qml` reports measured width and consumes service-derived drag targets

The service is the map; modules become viewers of that map.

### 5. Width measurement handshake

Widgets still know their own natural width best, so measurement starts in `BarWidgetWrapper`.
But instead of using that width directly as a private truth for drag and insertion logic, the wrapper reports it to `BarLayoutService` using its stable instance key.

The service then recalculates geometry and publishes updated slot positions.

Important rule: width changes must not reorder widgets or cause insertion index churn.
Order is owned only by the logical layout model; width affects boundaries, never semantic order.

### 6. Drag model

During drag, the service captures a drag snapshot:

- dragged instance key
- dragged widget id
- frozen drag width
- drag visual center x
- derived hover section
- derived ghost insertion index
- derived ghost line x

This prevents the dragged widget from visually jumping if its underlying content width changes mid-drag.
The drag width is frozen for the active session, while other section geometry continues to resolve around that fixed ghost size.

### 7. Picker anchoring

Widget picker placement is derived from the real section region center, not a third-of-bar estimate.
That keeps picker targeting aligned with what the user sees, especially when sections become asymmetrical.

## Data Flow

1. `BarWidgetWrapper` measures its content width and reports it to `BarLayoutService`.
2. `BarLayoutService` combines logical layout order, bar metrics, and measured widths.
3. The service derives section boundaries, slot geometry, picker anchors, and drag ghost geometry.
4. `BarSection`, `DropZone`, and `DragOverlay` render from those derived values.
5. Drag interactions report only pointer movement and instance identity back to the service.
6. On drop, the service resolves the final target section and order, then updates the persisted layout model.

## Error Handling And Fallbacks

- Missing width measurement falls back to a conservative default width so new widgets still participate in layout.
- Invalid section names or unknown instance keys are ignored with concise diagnostics.
- Geometry recomputation must clamp boundaries so no section produces negative width.
- If drag target computation becomes invalid during hot reload or widget teardown, drag state resets cleanly instead of leaving stale ghost data.

## Testing Strategy



- `BarLayoutService` exposes shared geometry state for section boundaries and slot metadata
- center-region logic stays visually centered under asymmetric widths
- insertion index remains stable when neighboring widget widths change
- picker target anchoring follows real section geometry
- drag ghost geometry updates from service state rather than direct `Row` child reads

Then run:

- `timeout 10 qs --path .`

## Affected Files

- `services/BarLayoutService.qml`
- `modules/bar/BarContent.qml`
- `modules/bar/BarSection.qml`
- `modules/bar/BarWidgetWrapper.qml`
- `modules/bar/DragOverlay.qml`
- `modules/bar/DropZone.qml`
- `modules/bar/BarWindow.qml`
- matching runner updates in `tests/run-*.sh` if new harnesses are introduced

## Non-Goals

- redesigning widget visuals or animation style tokens
- changing persistence schema beyond what is needed for runtime geometry
- introducing freeform snapping outside the existing left/center/right section model
- rewriting the whole bar into a fully absolute-positioned scene graph
