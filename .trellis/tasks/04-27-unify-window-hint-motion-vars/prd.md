# unify window hint motion vars

## Goal

Unify the motion amplitude and pulse-related constants used by `window hint`, `SuperIsland` transient messages, and `WorkspaceWidget` so the hint interaction feels consistent and all spring/pulse values come from one shared source.

## What I already know

* `Theme.qml` already owns shared animation tokens like `springDuration`, `springOvershoot`, `pulseSpringDuration`, and `pulseSpringOvershoot`.
* `WorkspaceWidget` and `SuperIsland` transient timelines already use those theme tokens directly.
* `IslandWindowHintCard` still has a local `_switchPulseScale` animation and the host currently derived extra scale/pulse behavior from the hint card.
* Current user request is to keep the behavior unified and move the numbers into variables instead of per-file literals.

## Assumptions (temporary)

* The desired unification is at the theme/token layer, not a behavior rewrite.
* It is acceptable to add a small number of shared hint-specific theme tokens if existing generic tokens are too broad.

## Open Questions

* None blocking yet; inspect existing token patterns first.

## Requirements (evolving)

* Window hint spring amplitude should be expressed via shared variables, not hardcoded per component.
* Window hint pulse scale should match the same shared motion family as transient/workspace.
* Existing transient and workspace motion should remain visually consistent after the unification.

## Acceptance Criteria (evolving)

* [ ] Window hint spring/pulse values are sourced from shared tokens or shared constants.
* [ ] `SuperIsland` transient and `WorkspaceWidget` still use the same shared motion family.
* [ ] `timeout 5 qs --path .` passes.

## Definition of Done (team quality bar)

* Tests added/updated where appropriate
* Lint / typecheck / CI green where applicable
* Docs/notes updated if behavior changes materially
* Rollout/rollback considered if risky

## Out of Scope (explicit)

* Reworking the whole SuperIsland rendering architecture
* Changing unrelated widget motion families

## Technical Notes

* Inspect `config/Theme.qml`, `modules/bar/superisland/SuperIslandTimelineTransient.qml`, `modules/bar/superisland/SuperIslandTimelinePulse.qml`, `modules/bar/widgets/WorkspaceWidget.qml`, and `modules/bar/superisland/IslandWindowHintCard.qml`.
