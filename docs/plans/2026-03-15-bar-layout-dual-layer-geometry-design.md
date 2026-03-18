# Bar Layout Dual-Layer Geometry Design

**Date:** 2026-03-15
**Status:** Approved
**Parent docs:**
- `docs/plans/2026-03-14-bar-layout-geometry-refactor-design.md`
- `docs/plans/2026-03-14-bar-layout-geometry-refactor-plan.md`
- `docs/plans/2026-03-15-bar-layout-geometry-teardown-safety-design.md`

## Overview

The current bar geometry refactor unified drag, slot, and picker logic in `BarLayoutService`, but layout mode still mixes two meanings of section width.
The overlay wants full-width docking regions, while `BarSection` still behaves like a content-sized strip whose width is driven by its `Row`.

That mismatch creates two visible problems:

- in layout mode, the three docking regions do not visually or interactively cover the full bar width
- when a widget is inserted to the right side of an existing left-section widget, the arriving widget can briefly appear centered on the docking point before shifting into its final slot

The fix is to separate the section's outer layout frame from its inner visual content band.

## Problems To Solve

- `DropZone` and picker targeting should treat left, center, and right as full-width docking regions in layout mode.
- `BarSection` should stop collapsing to content-width or zero-width containers when the service already knows the intended region frame.
- Inserted or moved widgets should land inside their final slot context immediately instead of animating from an ambiguous content-sized parent.
- Existing adaptive-content behavior must remain intact: the center content still stays visually centered, and left/right content still hugs their natural edges.

## Decision

Adopt a dual-layer geometry contract owned by `BarLayoutService`.

That means:

- section frame geometry fills the full usable bar width without gaps
- visual content geometry remains adaptive inside each frame
- outer containers and overlays consume frame geometry
- inner widget rows consume visual geometry

This is like giving each section a full parking bay while still letting the cars park naturally within that bay.

## Considered Approaches

### Recommended: Dual-layer geometry

Keep two coordinated geometry layers per section:

- frame geometry: the full docking and click region
- visual geometry: the adaptive content band inside that region

Pros:

- fixes both reported symptoms at the same architectural boundary
- preserves the current service-owned geometry model instead of backing away from it
- keeps center visual centering and adaptive content behavior intact
- gives overlays and real section containers the same outer shape

Cons:

- requires tightening the local-coordinate contract in `BarSection` and `BarLayoutService`
- may need one extra rule for suppressing the first width animation of a newly arriving delegate in layout mode

### Alternative: Overlay-only widening

Make `DropZone` fill the full bar width but leave `BarSection` content-sized.

Pros:

- small diff

Cons:

- fixes only the visible region-fill issue
- keeps the insertion-position bug because the actual section container still does not match the overlay frame

### Rejected: Full absolute-position rewrite

Rewrite section layout so every widget is positioned absolutely from service slot geometry.

Pros:

- maximum control over arrival and motion

Cons:

- much higher regression risk
- unnecessary for the problem at hand
- throws away working `Row` and delegate behavior that can still be reused

## Architecture

### 1. Frame geometry in `BarLayoutService`

`BarLayoutService.sectionGeometry(section)` keeps exposing `left`, `right`, `width`, and `centerX`, but those values now represent the section's full contiguous frame.

The three frames should cover the whole usable bar width with no gaps:

- left frame: usable left edge to center-frame left edge
- center frame: centered interaction band
- right frame: center-frame right edge to usable right edge

This preserves the existing section hit-testing intent while making layout mode feel like three real docking bays.

### 2. Visual geometry stays adaptive

`visualLeft`, `visualWidth`, and `visualCenterX` remain the source of truth for where content should actually render inside the frame.

That preserves the design goals from the earlier refactor:

- left content stays edge-aligned to the left
- right content stays edge-aligned to the right
- center content stays visually centered around the bar midpoint

The important distinction is that visual content no longer defines the outer section container.

### 3. Consumers split by responsibility

Use the geometry layers like this:

- `BarContent.qml`: position and size each `BarSection` from frame geometry
- `BarSection.qml`: keep the outer item at frame size, but offset `widgetRow` inside it using `visualLeft - left`
- `DragOverlay.qml` and `DropZone.qml`: paint and capture input from frame geometry
- slot computation in `BarLayoutService`: continue to place slots from `visualLeft`

The frame is the parking bay; the visual band is where the parked widgets line up.

### 4. Section-local coordinates must change

Today `BarSection` and insertion helpers effectively treat local coordinates as if the section started at `visualLeft`.
Once the outer section uses full frame width, that is no longer true.

So the contract must become:

- `localX` passed from `BarSection` is relative to frame `left`
- `insertionIndexForSectionX()` converts with `geometry.left + localX`
- `insertionIndicatorGeometry()` returns `sectionLocalX` relative to frame `left`

That keeps insertion lines and slot targeting aligned after the section widens.

### 5. Arrival behavior for inserted or moved widgets

The arriving widget should appear inside its final slot context immediately.
It must not first animate from a centered or content-collapsed parent frame.

The design preference is:

1. fix the parent frame mismatch first by widening `BarSection`
2. if the arrival still briefly overlaps due to first-time width animation, suppress that first width animation for layout-mode arrivals while keeping opacity and scale enter motion

This keeps the UX readable without reintroducing private geometry math in the UI layer.

## Data Flow

1. `BarWidgetWrapper` reports width to `BarLayoutService`.
2. `BarLayoutService` derives full section frames and inner visual bands.
3. `BarContent` sizes each `BarSection` from the frame geometry.
4. `BarSection` places its `widgetRow` inside the frame using the visual offset.
5. `DropZone` and picker targeting consume the same frame geometry, so layout mode covers the whole bar width.
6. Inserted and moved widgets resolve against slot geometry that is still anchored to the visual band.

## Error Handling And Fallbacks

- If measured widths are missing, the service continues to use fallback widths so widened frames still compute deterministically.
- If frame and visual geometry temporarily diverge during hot reload, the service should clamp values so no section width becomes negative.
- If an arrival-animation suppression path is needed, it should be limited to layout-mode insertion and not become a general-purpose animation escape hatch.

## Testing Strategy


Required coverage:

- section frames form a contiguous partition of the usable bar width
- rendered `BarSection` items use frame width rather than only content implicit width
- `DropZone` bounds still align with section frame geometry
- slot and insertion helpers remain aligned after the local-coordinate origin moves to frame space
- adding or moving a widget into the left section no longer starts from a visually centered overlap state

Then run:

- `timeout 10 qs --path .`

## Affected Files

- `services/BarLayoutService.qml`
- `modules/bar/BarContent.qml`
- `modules/bar/BarSection.qml`
- `modules/bar/BarWidgetWrapper.qml`
- `modules/bar/DragOverlay.qml`
- `modules/bar/DropZone.qml`

## Non-Goals

- redesigning widget visuals or changing theme tokens
- replacing `Row` with a fully absolute scene graph
- changing persistence schema beyond what geometry derivation already needs
