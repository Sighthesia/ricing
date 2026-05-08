# fix window hint title collapse target width

## Goal

Fix the `window hint` title background collapse target so the title lane returns to the normal SuperIsland width during collapse instead of shrinking toward an extremely small width.

## What I already know

* The bug is in the SuperIsland `window hint` collapse/exit path.
* `SuperIslandTrackGeometry.qml` currently routes `transitionCollapsedWidth` to `host._idleCollapsedWidthLive` during `bar-expanded` `hint-exit`.
* `SuperIslandWindowHintWidthResolver.js` keeps separate concepts for `collapsedWidthLive`, `collapsedWidth`, and `expandedWidth`, so this is likely a wrong width-owner selection rather than a missing measurement.

## Assumptions (temporary)

* The intended target width is the normal idle SuperIsland collapsed width, not the minimal live title/text measurement used by an intermediate return path.
* The fix should stay scoped to the title/background collapse target and avoid changing unrelated detached hint or overlay exit behavior.

## Open Questions

* Should the fix apply only to the `bar-expanded window hint` exit path, or to every `window hint` title collapse path that currently reuses the same width chain?

## Requirements (evolving)

* Keep the `window hint` title background from collapsing to an extremely small width during exit.
* Make the title background collapse target match the normal SuperIsland width.
* Preserve existing non-title motion timing and attached panel cleanup behavior.

## Acceptance Criteria (evolving)

* [ ] During `window hint` collapse, the title background no longer shrinks toward a tiny width.
* [ ] The title background lands on the normal SuperIsland width at the end of collapse.
* [ ] Existing non-`window hint` collapse paths still behave the same.

## Definition of Done (team quality bar)

* Full-shell validation runs successfully if the environment allows it.
* No unrelated width-chain regressions are introduced in SuperIsland collapse behavior.

## Out of Scope (explicit)

* Retiming unrelated `window hint` animations.
* Refactoring the full SuperIsland width ownership architecture.

## Technical Notes

* Suspect files:
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
  * `modules/bar/superisland/SuperIslandWidthChainGeometry.qml`
  * `modules/bar/superisland/SuperIslandWindowHintWidthResolver.js`
  * `modules/bar/widgets/SuperIslandWidget.qml`
* Relevant spec files should be added to `implement.jsonl` and `check.jsonl` before dispatching sub-agents.
