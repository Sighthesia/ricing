# brainstorm: fix superisland duplicate clock instance

## Goal

Ensure only one visible clock instance exists during bar-expanded SuperIsland window-hint handoff by propagating the shared-clock suppression flag into the live detached hint card path.

## What I already know

* The user can see two clock instances: one moving shared handoff clock and one stationary detached workspace clock.
* `sharedClockActive` was already passed into detached component variants created directly in `SuperIslandWidget.qml`.
* The actual live detached hint shown inside `AttachedExpansionPanelHost` is instantiated via `modules/bar/superisland/SuperIslandAttachedContentDeck.qml` `hintCardComponent`.
* That live path did not pass `sharedClockActive`, so the detached clock never hid during handoff.

## Requirements

* Propagate the shared handoff flag into the live detached hint card.
* Keep the detached steady-state clock hidden while the shared moving clock is active.
* Preserve current handoff architecture; fix only the missing property bridge.

## Acceptance Criteria

* [ ] Only one visible clock instance remains during handoff.
* [ ] The stationary workspace clock no longer remains visible while the shared clock is moving.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Live card path and measurement/direct component paths agree on shared-clock visibility state.
* Static shell validation passes.

## Technical Approach

Add `sharedClockActive` to `SuperIslandAttachedContentDeck.qml` and pass it into the live `IslandWindowHintCard` instance, then feed the flag from `SuperIslandWidget.qml` when constructing `_attachedContentDeck`.

## Out of Scope

* Reworking the handoff trajectory.
* Changing detached layout geometry.
* Adjusting title/workspace capsule motion.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/superisland/SuperIslandAttachedContentDeck.qml`
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
* Root cause: only direct/measure component paths received `sharedClockActive`; the live attached deck path did not.
* Validation command: `timeout 5 qs --path .`
