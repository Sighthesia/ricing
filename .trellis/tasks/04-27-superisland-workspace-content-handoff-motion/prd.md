# brainstorm: fix superisland workspace-content handoff motion

## Goal

Make the detached workspace content in bar-expanded SuperIsland move together with the lower workspace rectangle during reveal and collapse, so the clock text follows the panel's motion path instead of appearing to teleport into place.

## What I already know

* The previous attempt only changed the detached clock item's local `y`.
* `IslandWindowHintBarExpandedDetachedPresentation.qml` previously used a `Column`, which owns child positions and effectively neutralized manual `y` on children.
* `AttachedExpansionPanelHost.qml` reveals the lower panel by animating host `height` with `clip: true`; inner content was mostly stationary and merely became visible as the clip opened.

## Requirements

* The detached workspace content should visually travel with the lower panel reveal.
* The clock text should move continuously into its final row instead of snapping in.
* Keep the fix local to the detached bar-expanded hint path.

## Acceptance Criteria

* [ ] During bar-expanded window-hint reveal, workspace content visibly follows the lower panel expansion.
* [ ] The clock text no longer appears to instantly jump to the destination row.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Geometry ownership for detached content motion is corrected.
* Static shell validation passes.

## Technical Approach

Replace the detached presentation `Column` with an explicit motion layer whose `y` is derived from visible reveal progress, so the workspace stage and relocated clock move as one block while the clipped panel opens and closes.

## Out of Scope

* Rewriting the attached reveal state machine.
* Reworking title-lane animation ownership.
* Changing overlay deck behavior.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/AttachedExpansionPanelHost.qml`
  * `modules/bar/superisland/SuperIslandAttachedContentDeck.qml`
  * `modules/bar/superisland/IslandWindowHintWorkspaceStage.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
* Root cause: the reveal host clipped stationary content; the prior per-clock `y` tweak also conflicted with `Column` ownership.
* Validation command: `timeout 5 qs --path .`
