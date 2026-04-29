# brainstorm: fix title capsules hidden by single clock

## Goal

Restore persistent visibility of the bar-expanded title capsule row after the single-clock refactor, without changing the clock trajectory itself.

## What I already know

* The bar-expanded title capsules are rendered through the `_mainLoader` main card path.
* After switching to the shared single clock instance, `_mainLoader` was hidden whenever the shared clock was visible.
* Because the title capsules still live inside the main card, hiding `_mainLoader` hid the title row too.
* The row then only reappeared briefly during collapse, overlapping the clock near the end.

## Requirements

* Keep title capsules visible throughout bar-expanded window-hint.
* Do not reintroduce a second clock instance.
* Only separate title-card visibility from standalone clock visibility.

## Acceptance Criteria

* [ ] Title capsules remain visible during the full bar-expanded hint session.
* [ ] Shared moving clock still remains the only rendered detached clock instance.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Main loader visibility logic distinguishes bar-expanded window-hint cards from standalone idle clock content.
* Static shell validation passes.

## Technical Approach

Add a dedicated `_barExpandedMainCardVisible` guard in `SuperIslandWidget.qml` and only zero `_mainLoader.opacity` for shared-clock visibility when the main loader is not rendering the bar-expanded window-hint main card.

## Out of Scope

* Reworking clock motion.
* Changing title capsule geometry or stage logic.
* Altering detached workspace reveal timing.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedMainPresentation.qml`
  * `modules/bar/superisland/IslandWindowHintTitleCapsuleRow.qml`
* Root cause: `_mainLoader` owns both the bar-expanded title card and generic main content, so a blanket hide-for-clock rule also hid the title capsules.
* Validation command: `timeout 5 qs --path .`
