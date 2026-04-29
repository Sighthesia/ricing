# brainstorm: fix superisland clock window-hint motion

## Goal

Make the SuperIsland clock feel like it physically relocates into the lower workspace area when bar-expanded window hint opens, instead of appearing to teleport near the bottom.

## What I already know

* The issue occurs in bar-expanded window-hint presentation.
* The top host and lower detached panel are rendered by separate presentation branches.
* The detached clock already had fade/offset properties, but its vertical travel started too close to the destination.

## Requirements

* Preserve the existing bar-expanded window-hint structure.
* Keep the fix minimal and local to clock handoff motion.
* Make the lower clock travel from the upper handoff region down to its final row.

## Acceptance Criteria

* [ ] When window hint expands, the clock no longer appears to snap directly near the workspace bottom.
* [ ] The detached clock visibly travels downward into the lower lane.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Motion bug is fixed with a minimal QML change.
* Shell config validation passes.

## Technical Approach

Adjust the detached clock wrapper in `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml` so its initial `y` starts above the workspace lane by the full workspace-stage-plus-gap distance, then settles into the final clock row as `relocatedClockOpacity` approaches `1`.

## Out of Scope

* Reworking the window-hint state machine.
* Merging top and detached presentations into one shared moving element.
* Tuning unrelated width/shape animation.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedMainPresentation.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
* Validation command: `timeout 5 qs --path .`
