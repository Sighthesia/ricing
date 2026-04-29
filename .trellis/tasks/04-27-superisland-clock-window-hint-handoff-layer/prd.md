# brainstorm: fix superisland shared clock handoff layer

## Goal

Replace the visual clock teleport in bar-expanded SuperIsland window-hint with one continuous shared handoff path that moves a single visible clock instance from the top host into the lower detached workspace lane.

## What I already know

* The current bar-expanded hint is split into `bar-expanded-main` and `bar-expanded-detached` presentations.
* The top main presentation does not render a live outgoing clock; it only renders title capsules.
* The lower detached presentation reveals content through `AttachedExpansionPanelHost` height clipping.
* Previous fixes changed only detached content motion, which did not solve the missing cross-presentation clock handoff.

## Requirements

* Keep one visible clock instance during the handoff portion of bar-expanded hint reveal.
* Hide the regular top idle clock while the shared handoff clock is active.
* Hide the detached steady-state clock until the shared handoff completes.
* Reuse existing `IslandIdleClockCard` instead of cloning a second bespoke clock implementation.

## Acceptance Criteria

* [ ] The clock visibly travels from the bar host toward the detached workspace clock row.
* [ ] The handoff does not show two clocks at the same time during the active shared path.
* [ ] The detached steady-state clock takes over only after the shared handoff is effectively complete.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Shared handoff geometry ownership is explicit and localized.
* The detached card exposes a stable destination row for the shared handoff layer.
* Static shell validation passes.

## Technical Approach

Add a shared `IslandIdleClockCard` layer in `modules/bar/widgets/SuperIslandWidget.qml` and drive its `y` from the top idle clock position to the detached card's exported clock-row position using `_attachedVerticalRevealProgress`. Keep the lower detached presentation responsible for its steady-state layout, but suppress its own clock visibility while the shared handoff layer is active.

## Out of Scope

* Rewriting the overall hint state machine.
* Replacing the split main/detached presentation architecture.
* Tuning workspace capsule motion unrelated to the clock handoff.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
  * `modules/bar/superisland/SuperIslandAttachedContentDeck.qml`
  * `modules/bar/AttachedExpansionPanelHost.qml`
* Root cause: the top outgoing clock had no rendered owner, while the lower clock was only an incoming steady-state element revealed by clipping.
* Validation command: `timeout 5 qs --path .`
