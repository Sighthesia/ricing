# debug superisland hint exit fix still ineffective

## Goal

Determine why multiple attempted fixes for the bar-expanded `window-hint` exit timing/width regressions still do not match the user-visible behavior, and isolate the remaining mismatch without relying on speculative code changes.

## What I already know

* The user-visible issue has survived several rounds of fixes touching:
  * seam arc visibility,
  * collapsed width target,
  * helper-layer reveal drivers,
  * host width transition retarget behavior.
* Several of those fixes passed static shell validation, but the user still reports the problem in real behavior.
* This strongly suggests at least one of the following:
  * the wrong visual owner is still being targeted,
  * the right owner is being changed but not on the actually observed code path,
  * or a second owner/timing path still overrides the intended fix at runtime.

## Assumptions (temporary)

* This task is for debugging/root-cause isolation first, not for another speculative patch.
* The most valuable next step is to narrow the remaining mismatch to one concrete runtime/owner discrepancy.
* It may turn out that the user-visible symptom is owned by a different phase path than the one we have been modifying.
* The preferred next observation is the final end width, not the start timing.
* The expected final width reference is the normal idle SuperIsland collapsed width.

## Open Questions

* None currently.

## Requirements (evolving)

* Summarize which attempted fixes already landed and why they might still be ineffective.
* Identify the remaining most likely mismatch between runtime owner path and expected behavior.
* Reduce the next investigation to one observable runtime question rather than another broad fix.
* Focus this investigation on the title host's final exit width target first.
* Treat the normal idle SuperIsland collapsed width as the expected end-state reference.

## Acceptance Criteria (evolving)

* [ ] Prior attempted fixes are summarized concretely.
* [ ] The remaining mismatch is reduced to one specific runtime/owner hypothesis.
* [ ] The next investigation question is concrete enough to avoid another speculative patch.
* [ ] The expected final width reference is explicitly named.

## Definition of Done (team quality bar)

* The likely remaining mismatch is clearly framed in `prd.md`.
* The next step is a precise investigation target, not another broad code attempt.

## Out of Scope (explicit)

* Implementing yet another speculative code fix in this task.
* Large refactors.
* State-machine rewrites.

## Technical Notes

* Previously touched files include:
  * `modules/bar/superisland/SuperIslandSeamArcLayer.qml`
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
  * `modules/bar/superisland/SuperIslandWidthChainGeometry.qml`
  * `modules/bar/BarExpandTransition.qml`
  * `modules/bar/widgets/SuperIslandWidget.qml`
* Current strongest suspicion:
  * one remaining runtime-visible owner path still diverges from the code path we have been repairing.
