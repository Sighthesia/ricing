# debug superisland hint exit timing owner

## Goal

Determine the true timing owner for the bar-expanded `window-hint` title-host width retreat during `hint-exit`, and identify whether recent fixes targeted the wrong layer.

## What I already know

* The user-visible symptom is: the title background width retreat starts later than the workspace collapse retreat.
* Several fixes already tried adjusting `SuperIslandWidthChainGeometry.qml`, `SuperIslandTrackGeometry.qml`, and seam-arc visibility, but the user still reports the timing bug.
* Current analysis suggests the visible title background rectangle is owned by the host pill width chain (`_pillBg.width` -> `_pillClip.width` -> `_pillTransitionControl.animatedWidth`), not by the inner `IslandWindowHintCard` reveal progress alone.
* That means earlier fixes may have changed card/helper-layer inputs while the real timing owner remained in the host transition chain.

## Assumptions (temporary)

* This task begins as a debugging/root-cause task, but should include the minimal code fix if the owner chain is confirmed clearly enough.
* The likely root cause lives in width retarget timing rather than width target selection alone.
* The most suspicious files are `SuperIslandWidget.qml`, `BarExpandTransition.qml`, and `SuperIslandWindowHintWidthResolver.js`.

## Open Questions

* None currently.

## Requirements (evolving)

* Identify the true visual owner of the title host background width during `hint-exit`.
* Identify which property or timing source starts workspace collapse.
* Identify whether those two paths are owned by different drivers/timing sources.
* Explain why previous fixes did not resolve the observed symptom.
* Produce an actionable conclusion for the next repair step.
* If the owner chain is confirmed clearly enough, implement the smallest correct fix in the same task.

## Acceptance Criteria (evolving)

* [ ] The title host width owner is identified concretely.
* [ ] The workspace collapse width/geometry owner is identified concretely.
* [ ] The analysis explains why prior fixes missed the real owner.
* [ ] The next repair point is narrowed to one or two concrete symbols/files.
* [ ] If the cause is confirmed, the minimal fix is implemented and validated.

## Definition of Done (team quality bar)

* Root cause analysis is captured in `prd.md`.
* The likely repair boundary is narrowed enough to avoid further speculative fixes.
* If repaired, the change stays minimal and validated.

## Out of Scope (explicit)

* Large refactors.
* Rewriting the full hint state machine.
* Broad helper cleanup unrelated to this timing bug.

## Technical Notes

* Primary files to inspect:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/BarExpandTransition.qml`
  * `modules/bar/superisland/SuperIslandWindowHintWidthResolver.js`
  * `modules/bar/superisland/SuperIslandPillSurface.qml`
  * `modules/bar/superisland/SuperIslandCardComponentRegistry.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
* Current strongest hypothesis:
  * title host width retreat is owned by the host pill width transition chain,
  * workspace retreat is owned by attached reveal geometry,
  * the bug is caused by those two retreat chains starting from different timing sources.
