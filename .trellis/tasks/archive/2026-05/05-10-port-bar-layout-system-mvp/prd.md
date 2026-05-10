# Port Bar Layout System MVP

## Goal

Port the minimum reusable bar layout foundation from `DymicShell` into `afloat` so this project can evolve from a single hard-coded center island into a structured top bar with reusable zones and a layout service.

## Requirements

* Replace the direct top-panel composition in `shell.qml` with a reusable bar module entry.
* Add a top-level `modules/bar/BarWindow.qml` that renders one transparent top bar per screen.
* Add a `modules/bar/BarContent.qml` composition root with three zones: `left`, `center`, and `right`.
* Add a singleton `services/BarLayoutService.qml` that owns the default layout model for the bar.
* Add the minimum supporting barlayout helper files needed for section geometry and layout model access.
* Register the existing `modules/background/DynamicIslandDockZone.qml` as the first managed bar widget in the `center` section.
* Keep the existing `modules/background/ScreenCornerWindow.qml` behavior intact.
* Keep the implementation minimal and self-contained for this project; do not pull in unrelated DymicShell services or theme systems.

## Acceptance Criteria

* [ ] `shell.qml` instantiates a reusable bar window module instead of inlining the top panel.
* [ ] The project has dedicated bar modules for window/content/section/wrapper responsibilities.
* [ ] The project has a singleton layout service that exposes a default three-section layout model.
* [ ] The center zone renders the existing dynamic-island dock zone through the new managed layout path.
* [ ] The screen-corner overlay still loads alongside the new bar system.
* [ ] The new structure loads with available QML validation or shell startup checks.

## Definition of Done

* Minimum implementation is present and runnable.
* Validation is run with the repo's available QML or shell checks.
* No drag overlay, widget picker, context menu, settings panel, persistence, or unrelated widgets are introduced.

## Technical Approach

Port only the layout kernel from `DymicShell`: a bar window, a bar content root, section rendering, wrapper rendering, and a minimal layout service plus helper JS. Preserve `afloat`'s existing visual center island by treating `DynamicIslandDockZone.qml` as the first managed widget instead of replacing it with DymicShell widgets.

## Decision (ADR-lite)

**Context**: The reference project contains a large integrated shell system, but `afloat` is still minimal and should not absorb theme, settings, media, notification, or compositor-specific dependencies yet.

**Decision**: Port only the bar layout MVP and keep the existing center island as the only managed widget for now.

**Consequences**: This creates a clean migration seam for future widgets and layout management while keeping the current codebase small. It also means advanced interactions like drag sorting and widget management UI remain out of scope for this task.

## Out of Scope

* Right-click context menu
* Widget picker window
* Drag-and-drop reordering UI
* Layout persistence to disk
* Full DymicShell theme, color, or settings services
* Additional imported widgets such as clock, tray, media, or workspace widgets

## Technical Notes

* Current target entry file: `shell.qml`
* Current reusable visual widget: `modules/background/DynamicIslandDockZone.qml`
* Existing overlay to preserve: `modules/background/ScreenCornerWindow.qml`
* Reference files live in the sibling `DymicShell` repo and are summarized in `research/bar-layout-mvp-reference.md`
* Relevant frontend spec guidance is injected through `implement.jsonl` and `check.jsonl`
