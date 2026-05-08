# fix superisland hint exit collapsed width target

## Goal

Fix the remaining `window-hint` exit regression where the title host width retreats toward an overly small value instead of the normal SuperIsland collapsed width.

## What I already know

* The previous debugging/fix work made the title host width retreat start in sync with workspace collapse again.
* The user now reports that the exit target width is still wrong: it retreats toward a very small width instead of the normal/collapsed SuperIsland width.
* The likely owner chain for the visible title host width is still the host pill width chain (`_pillTransitionControl.animatedWidth` -> `_pillClip.width` -> `_pillBg.width`).
* Recent fixes touched `SuperIslandTrackGeometry.qml` and related helper timing sources.

## Assumptions (temporary)

* The remaining bug is about the final width target, not the start timing.
* The preferred fix is minimal and stays inside the existing host/helper ownership structure.
* No extra owner/helper cleanup should be bundled with this fix; only the exit target width rule should change.
* Loader ownership, state-machine ownership, and host export contracts must remain unchanged.

## Open Questions

* None currently.

## Requirements (evolving)

* Ensure the bar-expanded `hint-exit` width retreat targets the normal SuperIsland collapsed width.
* Do not regress the already-fixed start timing alignment with workspace collapse.
* Do not regress seam arc visibility.
* Do not bundle extra helper/owner cleanup beyond the width-target rule itself.
* Keep loader/state-machine/service ownership unchanged.
* Keep host export contract ownership on the host.

## Acceptance Criteria (evolving)

* [ ] Exit width target is the normal SuperIsland width, not an overly small width.
* [ ] Width retreat still starts in sync with workspace collapse.
* [ ] Seam/transition arc behavior remains correct.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done (team quality bar)

* Regression is fixed with minimal code changes.
* Full-shell validation passes.
* The target-width owner/rule is clearly identified.
* The scope stays limited to the width-target rule only.

## Out of Scope (explicit)

* Rewriting the state machine.
* Reworking the full host-slimming refactor.
* Additional helper cleanup unrelated to the width target.

## Technical Notes

* Most likely files to inspect:
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
  * `modules/bar/superisland/SuperIslandWidthChainGeometry.qml`
  * `modules/bar/superisland/SuperIslandWindowHintWidthResolver.js`
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/BarExpandTransition.qml`
* Current hypothesis:
  * the start timing fix is now correct,
  * but the width retreat target still resolves through the wrong collapsed-width source during `hint-exit`.
