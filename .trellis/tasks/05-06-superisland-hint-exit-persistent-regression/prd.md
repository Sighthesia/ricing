# debug persistent superisland hint exit regression

## Goal

Identify why the bar-expanded `window-hint` exit regression still persists after multiple timing/width fixes, and isolate the true visual owner and timing chain that still diverges from the expected behavior.

## What I already know

* The user-visible symptom remains: the title background width retreat still does not visually match the expected exit behavior, despite several fixes.
* Previous fixes already attempted:
  * seam arc visibility gating,
  * collapsed-width target repair,
  * title reveal driver changes,
  * width transition target/timing rewiring in `SuperIslandTrackGeometry.qml`.
* Multiple rounds passed static shell validation, but the user still reports the bug, which strongly suggests the earlier fixes targeted the wrong visual owner or the wrong timing chain.
* The likely width owner of the visible title host background is still the host pill width chain (`_pillTransitionControl.animatedWidth` -> `_pillClip.width` -> `_pillBg.width`).

## Assumptions (temporary)

* This is now a deep debugging task only, not another speculative patch task.
* The problem may be a mismatch between observed visual ownership and the properties we have been modifying.
* The next useful output should be a precise owner/timing map and one validated repair point, not another broad retry or implementation attempt.
* The preferred deliverable is a step-by-step symbol trace from user-visible symptom to the real owner/timing mismatch.

## Open Questions

* None currently.

## Requirements (evolving)

* Reconstruct the exact visible owner chain for the title host background width during `hint-exit`.
* Reconstruct the exact visible owner chain for workspace collapse during `hint-exit`.
* Explain why the previously changed symbols did not alter the user-visible behavior enough.
* Narrow the remaining bug to one concrete owner/timing mismatch.
* Do not implement a new code fix in this task.
* Produce the result as a step-by-step symbol trace, not just a short summary.

## Acceptance Criteria (evolving)

* [ ] The true title-width visual owner chain is identified concretely.
* [ ] The true workspace-collapse visual owner chain is identified concretely.
* [ ] The analysis explains why previous fixes missed the real cause.
* [ ] The next repair point is reduced to one concrete owner/timing mismatch.
* [ ] The output includes concrete symbol-level observation points for the next repair.

## Definition of Done (team quality bar)

* Root cause analysis is captured in `prd.md`.
* The next repair, if any, is based on explicit owner/timing evidence rather than symptom-level speculation.

## Out of Scope (explicit)

* Broad host/helper refactors.
* Rewriting the full state machine.
* Committing unrelated cleanup just because files are already open.

## Technical Notes

* Files most likely involved:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/BarExpandTransition.qml`
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
  * `modules/bar/superisland/SuperIslandWidthChainGeometry.qml`
  * `modules/bar/superisland/SuperIslandPillSurface.qml`
  * `modules/bar/superisland/SuperIslandAttachedRevealGeometry.qml`
  * `modules/bar/superisland/SuperIslandCardComponentRegistry.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
* Current strongest suspicion:
  * we have repeatedly changed helper-layer progress/target inputs,
  * but the user-visible width retreat may still be owned by a different host transition source or by a latched width path that was not actually retargeted.
