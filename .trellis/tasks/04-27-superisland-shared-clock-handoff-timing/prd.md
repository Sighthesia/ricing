# brainstorm: fix superisland shared clock handoff timing

## Goal

Remove the delayed clock chase after workspace-count changes and make the shared handoff clock participate in the real bar-to-detached travel path instead of being clipped inside the top host.

## What I already know

* The shared handoff clock was previously mounted inside `_pillClip`, which has `clip: true`.
* The detached destination row and the shared handoff layer both had extra `Behavior on y`, which caused visible lag when workspace content height changed.
* The user still observed teleport-like expand/collapse behavior and a delayed follow effect after workspace layout changes.

## Requirements

* The shared handoff clock must render outside the clipped top host.
* Reveal-driven geometry should come from one source of truth instead of adding a second y-animation layer.
* Workspace-count or workspace-layout changes must not make the clock chase the new target with delayed easing.

## Acceptance Criteria

* [ ] The shared handoff clock is no longer clipped by the top pill host.
* [ ] Workspace-count changes do not introduce delayed clock catch-up motion.
* [ ] Expand/collapse path now reflects direct reveal-driven geometry rather than a second trailing animation.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Shared clock ownership is moved to a non-clipped parent layer.
* Redundant `Behavior on y` paths are removed from reveal-owned geometry.
* Static shell validation passes.

## Technical Approach

Keep the shared clock handoff layer in `SuperIslandWidget.qml`, but mount it outside `_pillClip` and remove extra y-behaviors from the detached content reveal path so both the detached target row and the shared clock derive position directly from live reveal progress.

## Out of Scope

* Replacing the shared handoff approach.
* Rewriting workspace stage sizing logic.
* Tuning final target alignment beyond reveal/lag correctness.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
  * `modules/bar/superisland/SuperIslandAttachedContentDeck.qml`
* Root causes:
  * shared handoff clock was clipped by `_pillClip`
  * extra `Behavior on y` introduced delayed catch-up after workspace layout changes
* Validation command: `timeout 5 qs --path .`
