# brainstorm: fix title capsules reappear on final collapse

## Goal

Prevent the title capsule row from reappearing during the final collapse tail after the clock has already returned to the bar region.

## What I already know

* The previous fix hid title capsules during `hint-exit`, which removed the initial overlap.
* The user still observed title capsules reappearing later in the collapse tail.
* This means `_barExpandedMainCardVisible` became true again after `hint-exit` finished while the bar-expanded hint state was still not fully torn down.

## Requirements

* Title capsules should only be visible during the active `hint` display phase.
* Title capsules should stay hidden for the rest of the collapse lifecycle after exit begins.
* Do not alter clock motion or detached geometry.

## Acceptance Criteria

* [ ] Title capsules no longer reappear after the clock returns toward the SuperIsland region.
* [ ] Title capsules remain visible during the active `hint` phase only.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Main-card visibility is narrowed to the actual visible hint phase.
* Static shell validation passes.

## Technical Approach

Refine `_barExpandedMainCardVisible` in `SuperIslandWidget.qml` to require `root._phase === "hint"` instead of the looser `root._phase !== "hint-exit"` condition.

## Out of Scope

* Width-retreat timing changes.
* Shared clock path changes.
* Detached panel lifecycle changes.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
* Root cause: title-card visibility still allowed post-`hint-exit` tail phases where the main display event remained `window-hint`.
* Validation command: `timeout 5 qs --path .`
