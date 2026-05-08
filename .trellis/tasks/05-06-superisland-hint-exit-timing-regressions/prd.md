# fix superisland hint exit timing regressions

## Goal

Fix the `window-hint` exit timing regressions introduced during the SuperIsland host-slimming refactor so the bar-expanded title host, workspace collapse, and seam decoration retreat in sync again.

## What I already know

* The recent host-slimming refactor extracted multiple helper objects and visual leaf components out of `modules/bar/widgets/SuperIslandWidget.qml`.
* Regressions were reported after that refactor in bar-expanded `window-hint` exit:
  * seam/transition arc canvas disappeared too early,
  * title background width collapsed toward the wrong target width,
  * title background width shrink appeared to start later than workspace collapse.
* Earlier fixes already attempted:
  * restoring seam-arc visibility gating,
  * restoring the collapsed-width target to the normal SuperIsland width,
  * switching a title reveal progress source from `attachedVerticalRevealProgress` to `attachedRevealProgress`.
* The latest analysis suggests the true owner of the visible title background width is the host pill width chain (`_pillBg.width` / `_pillTransitionControl.animatedWidth`), not just the inner `IslandWindowHintCard` reveal progress.

## Assumptions (temporary)

* The bug is in timing/ownership wiring, not in theme tokens or measurement data itself.
* The preferred fix is minimal and preserves the host-slimming refactor structure.
* The only allowed structural cleanup is tightening the timing owner/driver boundary; no extra helper reshuffle should be bundled in.
* Loader ownership, state-machine ownership, and host export contracts must remain unchanged.

## Open Questions

* None currently.

## Requirements (evolving)

* Restore the seam/transition arc visibility through the seam-critical collapse range.
* Ensure title background width collapses toward the normal SuperIsland width, not an extremely small width.
* Ensure title background width shrink starts in sync with workspace collapse during `hint-exit`.
* Keep the host-slimming helper/component structure unless a tiny targeted rollback is strictly necessary.
* Only timing-owner rewiring/clarification is allowed as structural cleanup; do not bundle unrelated helper boundary changes.
* Do not move loader/state-machine/service ownership.

## Acceptance Criteria (evolving)

* [ ] The seam/transition arc remains visible through the intended collapse window.
* [ ] Title background width target is the normal SuperIsland width.
* [ ] Title background width begins shrinking at the same visible start point as workspace collapse.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done (team quality bar)

* Regression is fixed with minimal code changes.
* Full-shell validation passes.
* Root cause is captured clearly enough to avoid repeating speculative fixes.
* The fix leaves timing ownership easier to locate without broadening the refactor scope.

## Out of Scope (explicit)

* Reversing the full host-slimming refactor.
* Rewriting the state machine.
* Reorganizing the full `window-hint` architecture.

## Technical Notes

* Relevant files already identified:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/SuperIslandPillSurface.qml`
  * `modules/bar/superisland/SuperIslandSeamArcLayer.qml`
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
  * `modules/bar/superisland/SuperIslandWidthChainGeometry.qml`
  * `modules/bar/superisland/SuperIslandCardComponentRegistry.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
  * `modules/bar/BarExpandTransition.qml`
  * `modules/bar/superisland/SuperIslandWindowHintWidthResolver.js`
* Most important current hypothesis:
  * the visible title host background width is owned by the host pill width transition chain,
  * workspace collapse is owned by attached reveal geometry,
  * the current regression likely comes from those two owners starting their retreat on different timing sources.
