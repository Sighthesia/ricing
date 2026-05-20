# Edge-Attached Side Dockzone Ears

## Goal

Adjust the left and right bar dock zones so they sit flush against the screen edges and use a side-specific attached-ear silhouette instead of the current symmetric two-ear background.

## What I already know

* `modules/bar/BarContent.qml` anchors the left section to `parent.left` and the right section to `parent.right`.
* `modules/bar/BarSection.qml` currently renders every section through the shared `modules/bar/BarDockZoneBackground.qml`.
* `modules/bar/BarDockZoneBackground.qml` currently always paints two top-side ears plus one rounded body, so side sections cannot have edge-specific geometry yet.

## Assumptions (temporary)

* Only the left and right dock zones should change shape in this task.
* The center dock zone should keep the current two-ear attached-island silhouette unless you say otherwise.

## Open Questions

* None.

## Requirements (evolving)

* Left and right dock zones should stay flush with their respective screen edges.
* Side dock zones should use one rotated ear attached at the rectangle bottom instead of the current mirrored two-ear layout.
* The single side ear should sit on the inner-bottom corner.
* The center dock zone should keep the current two-ear attached-island silhouette.

## Acceptance Criteria (evolving)

* [ ] Left dock zone visually touches the left screen edge with no floating ear gap.
* [ ] Right dock zone visually touches the right screen edge with no floating ear gap.
* [ ] Left dock zone renders a single rotated ear on its inner-bottom corner.
* [ ] Right dock zone renders a single rotated ear on its inner-bottom corner.
* [ ] Center dock zone behavior remains unchanged.

## Definition of Done

* Relevant QML files updated with minimal changes.
* `qmllint` passes for affected bar modules.
* No unintended shape regression for the center dock zone.

## Out of Scope (explicit)

* Reworking the widget layout model.
* Changing picker behavior or widget registry behavior.
* Redesigning the center dock zone unless required by the final decision.

## Technical Notes

* Likely affected files: `modules/bar/BarDockZoneBackground.qml`, `modules/bar/BarSection.qml`, possibly `modules/bar/BarContent.qml`.
* The current shared background likely needs section-aware shape parameters instead of a full duplicate component.

## Technical Approach

Introduce section-aware geometry into `BarDockZoneBackground.qml` so side sections can switch from the current symmetric two-ear shape to a screen-edge-attached variant without duplicating the whole component.

## Decision (ADR-lite)

**Context**: Side dock zones need a different silhouette from the center zone, but all three sections currently share one background component.

**Decision**: Keep one shared background component and add section-aware drawing rules so left/right sections can attach flush to the screen edge and place one rotated ear on the inner-bottom corner.

**Consequences**: This keeps the change small and preserves component reuse, but the shared background file will own a bit more branchy shape logic.
