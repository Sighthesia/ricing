# brainstorm: fix title capsules overlap on exit

## Goal

Make the bar-expanded title capsule row leave as soon as clock return/exit begins, instead of staying visible until the host width shrink finishes and overlapping the returning clock.

## What I already know

* Title capsules are rendered through `_mainLoader` when it shows the bar-expanded main hint card.
* Their visibility was previously tied to `_barExpandedHintActive`, which remains true through the `hint-exit` width-retreat phase.
* Because of that, title capsules stayed on screen while the single shared clock was already returning toward the bar host, causing overlap.

## Requirements

* Title capsules should remain visible during active bar-expanded hint display.
* Title capsules should hide as soon as the exit phase starts.
* The change must not alter the clock trajectory or detached geometry.

## Acceptance Criteria

* [ ] Title capsules no longer overlap the returning clock during `hint-exit`.
* [ ] Title capsules still display normally during the active bar-expanded hint phase.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Main-card visibility is gated by phase, not only by bar-expanded width state.
* Static shell validation passes.

## Technical Approach

Refine `_barExpandedMainCardVisible` in `SuperIslandWidget.qml` so it requires `root._phase !== "hint-exit"` in addition to the existing bar-expanded window-hint checks.

## Out of Scope

* Reworking exit width timing.
* Changing the shared clock travel path.
* Retuning detached panel collapse.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedMainPresentation.qml`
  * `modules/bar/superisland/SuperIslandWindowHintWidthResolver.js`
* Root cause: title-card visibility followed the broader bar-expanded active state instead of the user-visible display phase.
* Validation command: `timeout 5 qs --path .`
