# brainstorm: fix superisland clock center alignment

## Goal

Tighten the final handoff so the moving clock aligns to the real detached steady-state clock center instead of approximating the target from the detached row's top edge.

## What I already know

* Prior fixes improved gross alignment but still left a small visual offset at the end of handoff.
* The previous target used detached row `y` (plus fallback math), which is only an approximation of the final visual center.
* `SuperIslandAttachedContentDeck.qml` applies `anchors.margins: 1`, so the live detached card sits 1 px below the raw panel host origin.
* Shared moving clock and detached steady-state clock now already share the same height contract (`Theme.barWidget.pillHeight`).

## Requirements

* Shared handoff clock should target the live detached clock's real center, not just the row top.
* Detached loader margin must be accounted for in the target coordinate.
* Keep the change local to the handoff end-position math.

## Acceptance Criteria

* [ ] The moving clock no longer finishes slightly offset from the final detached clock position.
* [ ] The shared clock aligns to the detached steady-state clock center at handoff completion.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* `IslandWindowHintCard` exports detached clock center coordinates.
* `SuperIslandWidget` computes handoff using center-to-center interpolation.
* Static shell validation passes.

## Technical Approach

Expose `relocatedClockCenterY` from `IslandWindowHintCard.qml`, derived from the detached presentation row plus half the final clock height. Then update `SuperIslandWidget.qml` to interpolate between the shared clock start center and the detached live clock target center, including the detached loader's 1 px margin.

## Out of Scope

* Reworking the handoff trigger threshold.
* Recomputing text baseline geometry inside `IslandIdleClockCard`.
* Changing workspace reveal or shell motion.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandIdleClockCard.qml`
* Root cause: end-position math targeted detached row top-edge geometry rather than the live steady-state clock center.
* Validation command: `timeout 5 qs --path .`
