# brainstorm: fix superisland clock end-position snap

## Goal

Remove the final fade-and-snap mismatch where the shared moving clock reaches the workspace bottom, fades, then appears to jump slightly upward into the detached steady-state clock target.

## What I already know

* The shared handoff clock uses `IslandIdleClockCard` in `SuperIslandWidget.qml`.
* The detached steady-state clock row also uses `IslandIdleClockCard` in `IslandWindowHintBarExpandedDetachedPresentation.qml`.
* The shared handoff clock previously used `cardHeight: _windowHintSideHeight`, while the final detached clock used `cardHeight: _barExpandedDetachedClockHeight` / `Theme.barWidget.pillHeight`.
* This made the moving clock and the final target have different height contracts, so even with the same row y they did not align visually at the end of handoff.

## Requirements

* Shared moving clock and final detached clock must use the same height contract.
* Fallback target calculations must also use the same final detached clock height.
* Keep the fix minimal and local to end-position alignment.

## Acceptance Criteria

* [ ] The shared clock no longer fades out and snaps upward into a slightly different final resting position.
* [ ] Shared moving clock and detached steady-state clock align visually at handoff completion.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done

* Shared and steady-state clock layers agree on size and end-position assumptions.
* Static shell validation passes.

## Technical Approach

Use `root._pillH` for the shared handoff clock and for its fallback target calculation so the moving clock matches the detached steady-state clock's `Theme.barWidget.pillHeight` contract.

## Out of Scope

* Reworking the handoff trajectory math.
* Global-center measurement of inner text baselines.
* Changing workspace panel reveal behavior.

## Technical Notes

* Relevant files inspected:
  * `modules/bar/widgets/SuperIslandWidget.qml`
  * `modules/bar/superisland/IslandWindowHintBarExpandedDetachedPresentation.qml`
  * `modules/bar/superisland/IslandIdleClockCard.qml`
  * `modules/bar/superisland/IslandWindowHintCard.qml`
* Root cause: moving clock and final target used different `cardHeight` contracts.
* Validation command: `timeout 5 qs --path .`
