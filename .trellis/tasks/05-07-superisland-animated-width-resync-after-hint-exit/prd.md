# fix superisland animated width resync after hint exit

## Goal

Fix the remaining `window-hint` exit bug where the visible pill width (`_pillTransitionControl.animatedWidth`) stays stuck at a very small value after exit completes instead of resyncing to the normal idle SuperIsland width.

## What I already know

* Target-width debugging logs show that after `completeWindowHintExit()`, the width targets already recover to the normal idle width values.
* However, the actual visible width owner (`_pillTransitionControl.animatedWidth`) stays at `20`, and the host export values (`layoutMeasurementWidth`, `implicitWidth`) also stay at `20`.
* This strongly indicates the remaining bug is not target selection anymore, but that the visible width owner never resyncs after the exit path completes.
* The most likely cause is around `freezeCollapsedWidthRetargeting` and/or the post-exit width retarget path inside `BarExpandTransition.qml`.

## Assumptions (temporary)

* The preferred fix is minimal and focused on width resync after `hint-exit` completes.
* Loader ownership, state-machine ownership, service ownership, and host export contracts must remain unchanged.
* This task should not reopen seam arc or width-target math unless directly required by the width resync bug.

## Open Questions

* None currently.

## Requirements (evolving)

* Ensure `_pillTransitionControl.animatedWidth` resyncs to the normal idle SuperIsland width after `completeWindowHintExit()`.
* Preserve the previously fixed seam arc behavior.
* Preserve the previously fixed start timing behavior.
* Preserve the previously fixed collapsed width target logic.
* Do not move loader/state-machine/service ownership.
* Do not bundle unrelated helper cleanup.

## Acceptance Criteria (evolving)

* [ ] After exit completes, visible pill width no longer stays stuck at the tiny value.
* [ ] Final visible width lands at the normal idle SuperIsland width.
* [ ] Seam arc behavior remains correct.
* [ ] Start timing remains correct.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done (team quality bar)

* The animated width resync bug is fixed with minimal code changes.
* Full-shell validation passes.
* The fix clearly targets the real visible width owner path.

## Out of Scope (explicit)

* Reworking the full host-slimming refactor.
* Rewriting the state machine.
* Broad helper consolidation.

## Technical Notes

* Primary files to inspect:
  * `modules/bar/BarExpandTransition.qml`
  * `modules/bar/widgets/SuperIslandWidget.qml`
* Key proven observation from the previous debug task:
  * width targets recover to normal values,
  * but `_pillTransitionControl.animatedWidth` does not resync,
  * so the bug is in the post-exit visible width owner/resync path.
