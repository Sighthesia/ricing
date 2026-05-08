# Fix Persistent Bar Region After Window Hint Re-entry

## Goal

Fix the persistent clickable bar region that remains below the visible SuperIsland bar after `window-hint` expands, exits, and re-enters, so the bar window height and hit region match the real top bar footprint instead of keeping stale lower attached-panel reservation.

## What I already know

* After `window-hint` expands, a persistent region remains from the bottom of the bar toward the workspace rectangle area.
* Right-clicking that region opens the bar menu.
* Opening the full expanded panel can temporarily clear it, but the region returns when `window-hint` expands again.
* Previous fixes that narrowed `layoutContextMenuHeight` and added local intercept layers did not solve the issue.
* Research points to the real owner chain being `SuperIslandWidget` -> `BarLayoutService.barTransientExtension` -> `BarWindow.implicitHeight` -> `BarContent` background `MouseArea`.

## Assumptions (temporary)

* The main bug is stale vertical reservation, not only stale widget-level right-click handling.
* The minimal correct fix will likely target overlay reservation cleanup/rebasing on `window-hint` re-entry or exit completion.
* `window-hint` bar-expanded mode should keep the visible top bar footprint and the lower attached-panel reservation on separate ownership paths.

## Open Questions

* None currently blocking.

## Requirements (evolving)

* Remove the persistent lower clickable region after `window-hint` expands, exits, and re-enters.
* Ensure bar background right-click behavior no longer treats stale lower reservation as valid bar area.
* Keep the visible top bar footprint aligned with actual bar window height and hit region.
* Scope this task to the `window-hint` re-entry stale reservation path only; do not proactively normalize unrelated detached-hint or overlay reservation paths in the same change.
* Preserve the existing `window-hint` / attached-panel motion behavior unless directly required for the fix.
* Keep shell validation passing via `timeout 5 qs --path .`.

## Acceptance Criteria (evolving)

* [ ] After `window-hint` expands and re-enters, no persistent clickable region remains below the visible bar footprint.
* [ ] Right-clicking the previously affected lower area no longer opens the bar menu.
* [ ] Full expanded panel behavior still works and does not regress attached-panel reveal/collapse motion.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Root cause is fixed at the real geometry/reservation owner, not only masked at a local input layer.
* Related geometry ownership remains understandable and extendable.
* Validation passes.

## Out of Scope (explicit)

* Broad redesign of all SuperIsland geometry ownership.
* Proactive cleanup of other reservation paths outside the confirmed `window-hint` re-entry chain.
* Unrelated motion-language cleanup.
* Reworking non-window-hint bar widgets.

## Technical Notes

* Primary research references:
  * `../05-04-superisland-step3-motion-geometry-ownership/research/persistent-bar-region-root-cause-reanalysis.md`
  * `../05-04-superisland-step3-motion-geometry-ownership/research/superisland-motion-geometry-ownership-analysis.md`
* Key files likely involved:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/BarWindow.qml`
  * `modules/bar/BarContent.qml`
  * `modules/bar/BarWidgetWrapper.qml`
  * `modules/bar/superisland/SuperIslandStateMachineOverlayPolicy.qml`
  * `modules/bar/superisland/SuperIslandStateMachineTransientPolicy.qml`
  * `modules/bar/superisland/SuperIslandStateMachineTimelineCallbacks.js`
