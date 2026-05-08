# fix superisland bar expand exit retarget timing

## Goal

Fix the bar-expanded `window-hint` exit timing so the upper title-host background width retreat starts on the correct owner timeline, matching the intended workspace collapse timing.

## What I already know

* Previous fixes changed helper-layer progress/target inputs but the user still reported the visible timing bug.
* Root-cause analysis indicates the real visual owner of the title host background width is the host pill width chain:
  * `_pillTransitionControl.animatedWidth`
  * `_pillClip.width`
  * `SuperIslandPillSurface.qml` `_pillBg.width`
* The workspace collapse is owned by the attached reveal/collapse chain, not by the host pill width owner.
* The most likely remaining bug is in the exit retarget timing/behavior of `BarExpandTransition` and its host-level inputs.

## Assumptions (temporary)

* The preferred fix is minimal and focused on the upper host width owner.
* Loader ownership, state-machine ownership, service ownership, and host export contracts must remain unchanged.
* This task should not reopen helper-layer speculation unless required to feed the real owner.
* The fix may touch both `BarExpandTransition.qml` and `SuperIslandWidget.qml` if that is the smallest way to correct the true owner timing.

## Open Questions

* None currently.

## Requirements (evolving)

* Fix the upper title-host width retreat timing on the real visible owner path.
* Preserve the already-fixed seam arc visibility.
* Preserve the already-fixed collapsed width target.
* Changes may include both `BarExpandTransition.qml` and `SuperIslandWidget.qml`, but only if strictly required by the real owner chain.
* Do not move loader/state-machine/service ownership.
* Do not bundle unrelated helper cleanup.

## Acceptance Criteria (evolving)

* [ ] The upper title-host width retreat starts at the intended time relative to workspace collapse.
* [ ] Seam arc behavior remains correct.
* [ ] Collapsed width target remains the normal SuperIsland width.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done (team quality bar)

* The timing regression is fixed on the real owner path.
* Validation passes.
* The change stays narrowly scoped.

## Out of Scope (explicit)

* Reworking the full host-slimming refactor.
* Rewriting the state machine.
* Broad helper consolidation.

## Technical Notes

* Primary files to inspect:
  * `modules/bar/BarExpandTransition.qml`
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
  * `modules/bar/superisland/SuperIslandWindowHintWidthResolver.js`
* Most likely bug class:
  * upper title host width retreat is still on a different retarget/spring timeline than lower workspace collapse,
  * even though helper-layer targets/progress values were adjusted.
