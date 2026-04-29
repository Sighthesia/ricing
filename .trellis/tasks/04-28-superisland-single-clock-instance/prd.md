# brainstorm: refactor superisland to single clock instance

## Goal

Convert the bar-expanded SuperIsland window-hint clock handoff from a multi-instance visibility swap into a true single-instance design, where the same `IslandIdleClockCard` travels from the top host into the detached workspace clock slot.

## What I already know

* Previous iterations used two `IslandIdleClockCard` instances: one shared moving clock and one detached steady-state clock.
* Visibility gating could hide one instance, but end-of-handoff alignment and perceived snapping remained sensitive because control still transferred between instances.
* The detached clock row already provides stable geometry that can be reused as a target without rendering a second clock instance.

## Requirements

* Remove the detached steady-state `IslandIdleClockCard` instance from the detached presentation.
* Keep one shared `IslandIdleClockCard` visible through the whole `bar-expanded` hint lifecycle.
* Preserve the detached clock row as a geometry anchor for the moving shared clock.

## Acceptance Criteria

* [ ] Only one rendered `IslandIdleClockCard` participates in the `bar-expanded` detached hint path.
* [ ] The detached row remains as a target slot, not as a second rendered clock.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* The detached path no longer renders a second steady-state clock instance.
* Shared clock visibility remains active for the full bar-expanded hint session.
* Static shell validation passes.

## Technical Approach

Remove the inner `IslandIdleClockCard` from `IslandWindowHintBarExpandedDetachedPresentation.qml` and keep only the `_clockRow` geometry. Then update `SuperIslandWidget.qml` so the shared clock remains visible whenever bar-expanded hint content is active, not only during the initial handoff phase.

## Out of Scope

* Reworking workspace stage geometry.
* Changing overlay handoff behavior.
* Replacing the clock card design itself.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/SuperIslandAttachedContentDeck.qml`
  * `modules/bar/superisland/IslandIdleClockCard.qml`
* Root cause addressed: multi-instance clock ownership caused handoff artifacts and made perfect end-position alignment harder.
* Validation command: `timeout 5 qs --path .`
