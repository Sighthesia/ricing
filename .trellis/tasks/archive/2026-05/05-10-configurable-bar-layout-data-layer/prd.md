# Configurable Bar Layout Data Layer

## Goal

Upgrade the current MVP bar layout from a hard-coded center-only model into a configurable layout data layer that can support multiple widgets, stable ordering, future editing flows, and local persistence.

## What I already know

* The project already has a minimal bar shell structure under `modules/bar/` and `services/`.
* `services/BarLayoutService.qml` currently exposes a static `layoutModel` from `services/barlayout/BarLayoutLayoutModel.js`.
* `modules/bar/BarSection.qml` currently renders widgets by reading `sectionWidgets(sectionName)` and resolving each entry's `source`.
* The current default layout contains only the existing `DynamicIslandDockZone.qml` in the `center` section.

## Assumptions (temporary)

* This task should define a stable widget entry schema and normalized section ordering.
* This task should include local persistence that can restore the saved layout on startup.

## Open Questions

* None currently.

## Requirements (evolving)

* Replace the current static bare object layout with a stable, configurable layout structure.
* Define the minimum widget entry contract needed for future add/remove/reorder behavior.
* Support multiple instances of the same widget type from the beginning.
* Persist the layout model locally and restore it on startup.
* Keep the current visual output working with the existing center dynamic island.
* Keep the implementation compatible with future widget-picker and drag-editing work.

## Acceptance Criteria (evolving)

* [ ] The layout model is no longer a trivial hard-coded shape tied only to the current center widget.
* [ ] Section rendering reads from a stable data contract suitable for future editing features.
* [ ] Widget entries have stable identity suitable for duplicate widget instances.
* [ ] The current default bar still renders correctly.
* [ ] The layout is saved locally and restored on the next startup.

## Definition of Done (team quality bar)

* QML validation passes
* New data-layer behavior is documented in task notes/research if needed
* No unrelated bar interaction UI is introduced unless explicitly required

## Out of Scope (explicit)

* Drag-and-drop editing UI
* Widget picker UI
* Right-click context menu
* Full DymicShell settings/theme migration

## Technical Approach

Adopt the smaller useful subset of DymicShell's layout model and persistence patterns. Use a stable widget-entry schema with `id`, `section`, `order`, `enabled`, and `instanceKey`, keep a default layout in code, normalize persisted layouts on load, and persist the current layout to a local `.state/layout.json` path.

## Decision (ADR-lite)

**Context**: Future configurable bar work will need duplicate widgets, reordering, and startup restoration. Deferring identity or persistence would force a schema change in the next task.

**Decision**: Include both local persistence and multi-instance widget identity in this task.

**Consequences**: The task is slightly broader than an in-memory refactor, but it creates a stable foundation for later picker and drag-editing work without a second data-model migration.

## Technical Notes

* Relevant current files: `services/BarLayoutService.qml`, `services/barlayout/BarLayoutLayoutModel.js`, `modules/bar/BarSection.qml`
* Prior MVP task: `05-10-port-bar-layout-system-mvp`
* Reference persistence and instance-key patterns from DymicShell should be reduced to the smallest subset needed here.
