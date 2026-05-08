# fix window hint idle width latch remains empty

## Goal

Fix the remaining `bar-expanded window-hint` exit width regression where the normal idle width latch remains `0`, allowing `transitionCollapsedWidth` to stay at the polluted tiny live value (`20`) and making the title/background collapse to an extremely small width.

## What I already know

* This continues the failed `window-hint-title-collapse-target-width` fix.
* User retest logs still show `transitionCollapsedWidth=20` and `pillAnimatedWidth=19` during `completeWindowHintExit:enter`.
* The latest logs now include `latchedIdleCollapsedWidth=0`, proving the latch never captured a usable normal idle width.
* After reset, normal idle width is still visible in the geometry chain: `collapsedWidth=110`, `transitionCollapsedWidth=110`, `pillAnimatedWidth=110`, and `attachedPanelVisibleWidth=110`.
* Prior attempts using `_idleCollapsedWidthLive` failed because it remains polluted at `20` during and even after this transition.

## Requirements

* Ensure `bar-expanded + hint-exit + window-hint` `transitionCollapsedWidth` resolves to the normal idle SuperIsland width, not `20` and not the expanded/attached width such as `748` or `880`.
* Capture or derive the normal idle width from a stable source that survives the bar-expanded hint presentation.
* Keep the fix scoped to `bar-expanded window-hint` exit.
* Preserve non-window-hint, non-bar-expanded, detached hint, overlay, and cleanup behavior.
* Keep debug output behind existing debug environment flags only.

## Acceptance Criteria

* [ ] During `completeWindowHintExit:enter`, `latchedIdleCollapsedWidth` is non-zero and close to the normal idle SuperIsland width when a normal idle target is available.
* [ ] During `hint-exit`, `transitionCollapsedWidth` is close to normal idle width (for example `110` in the provided logs), not `20`.
* [ ] `transitionCollapsedWidth` does not become the expanded/attached bar-expanded width (`748`/`880`).
* [ ] No behavior changes are introduced for non-window-hint and non-bar-expanded paths.
* [ ] Full-shell validation passes with `timeout 5 qs --path .`.

## Definition of Done

* Implementation is reviewed by `trellis-check`.
* `timeout 5 qs --path .` passes.
* New or updated spec guidance is captured if the final stable-width source reveals a reusable convention.

## Out of Scope

* Retiming the window hint animation.
* Refactoring the entire SuperIsland width ownership model.
* Removing unrelated debug instrumentation from other active tasks.

## Technical Notes

* Suspect files:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/SuperIslandTrackGeometry.qml`
  * `modules/bar/superisland/SuperIslandWidthChainGeometry.qml`
  * `modules/bar/superisland/SuperIslandWindowHintWidthResolver.js`
* Latest failing log proves the current latch is empty:
  * `latchedIdleCollapsedWidth=0`
  * `transitionCollapsedWidth=20`
  * `collapsedWidthLive=20`
  * `idleCollapsedWidthLive=20`
  * `collapsedWidth=748`
  * `attachedPanelVisibleWidth=748`
  * post-reset normal idle width: `collapsedWidth=110`, `transitionCollapsedWidth=110`, `attachedPanelVisibleWidth=110`, `pillAnimatedWidth=110`
