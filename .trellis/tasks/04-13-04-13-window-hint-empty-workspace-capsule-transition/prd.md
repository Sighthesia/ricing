# PRD

## Title

Fix window hint empty workspace capsule transition

## Problem

When the active workspace changes between a non-empty workspace and an empty workspace in the `window-hint` card, the empty workspace capsule appears and disappears instantly instead of participating in the existing cover-flow transition.

There is also a redundant retiring workspace capsule that briefly drops downward from a slightly elevated position during the exit path.

## Goal

Make empty and non-empty workspace switches use the same stage-driven cover-flow motion as other workspace transitions, with no instant pop-in/pop-out and no stray retiring capsule.

## Scope

- Keep the existing `WindowHintService` data contract intact unless the bug proves to be caused by missing stage data.
- Prefer a minimal fix inside the `window-hint` workspace stage visibility / slot assignment path.
- Preserve the current motion language, sizing, and timing as much as possible.

## Acceptance Criteria

- Switching from the last non-empty workspace to an empty workspace animates through the existing workspace stage motion instead of snapping.
- Switching from an empty workspace back to a non-empty workspace animates through the same motion path.
- No extra retiring workspace capsule lingers above the stage and slides downward on exit.
- Existing non-empty to non-empty workspace transitions remain unchanged.
- `timeout 5 qs --path .` passes.

## Notes

- Current suspected boundary: `services/WindowHintService.qml` -> `modules/bar/superisland/IslandWindowHintCard.qml` -> `IslandWindowHintStage.js` / `IslandWindowHintMotion.js` / `IslandWorkspaceStageCapsule.qml`.
