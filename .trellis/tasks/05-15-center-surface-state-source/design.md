# Design: Map Center Surface State from Content Presence

## Goal

Give the center dockzone a real semantic `surfaceState` source without introducing a new service layer, by mapping existing center content presence into dockzone state semantics.

## Architecture

```text
BarLayoutService.sectionWidgets("center")
   -> BarSection.sectionModel
   -> local semantic mapping layer in BarSection
   -> DockzoneSurfaceRoot.surfaceState
   -> owner-local progress drivers
```

## Why Content Presence

The center dockzone is fundamentally a surface that exists to frame center content.

That makes this mapping the closest semantic fit for a first real source:

- content exists -> surface should be `attached`
- content absent -> surface should be `hidden`

This is cleaner than letting widget-picker visibility define dockzone meaning, and it matches an existing project pattern where side ear visibility already depends on section content presence.

## Boundaries

### `BarSection.qml`

Owns the lightweight semantic mapping layer for the center path.

Responsibilities:

- inspect `sectionModel`
- compute whether the center section currently has visible content intent
- map that intent into a dockzone semantic state string
- pass only the resulting semantic state to `DockzoneSurfaceRoot`

It should not:

- own animation progress
- create a new shared service
- expand this mapping to left/right in this task

### `DockzoneSurfaceRoot.qml`

Keeps owning:

- semantic state consumption
- animated canonical progress drivers
- center surface rendering

No new public raw progress inputs should be added.

## Mapping Policy

First-pass mapping:

- center has content -> `attached`
- center has no content -> `hidden`

The owner already translates semantic state changes into progress animations. This task only replaces the hardcoded semantic source.

## Data Flow

1. `BarLayoutService.sectionWidgets("center")` returns the live center widget list.
2. `BarSection.qml` computes `hasCenterContent` from `sectionModel.length > 0`.
3. `BarSection.qml` maps that boolean to a semantic state string.
4. `DockzoneSurfaceRoot.qml` receives that semantic state.
5. Existing owner-local progress drivers animate the surface accordingly.

## Trade-offs

- Benefit: the dockzone meaning stays aligned with content presence instead of unrelated UI chrome.
- Benefit: smallest implementation; likely only one code file needs semantic wiring.
- Benefit: no new service or helper layer is required yet.
- Cost: because the default center layout always contains a placeholder widget, the visible behavior change may be subtle until future tasks allow the center section to become empty.

## Compatibility Notes

- Left/right legacy paths remain untouched.
- `BarLayoutService.qml` remains unchanged.
- `WidgetPickerWindow.qml` remains driven by `widgetPickerVisible`; this task does not redefine picker behavior.

## Rollback Shape

- Revert the center `surfaceState` binding in `BarSection.qml` back to the hardcoded `"attached"` value.
- Keep `DockzoneSurfaceRoot.qml` and `DockzoneSurfaceModel.js` unchanged.
