# Workspace Hint Coverflow Workspace Switching Design

## Summary

Replace the current fixed three-capsule workspace hint stack with a fixed camera viewport that keeps all workspace capsules alive while `mod` is held. Workspace switching should read as a vertical coverflow-like scroll: every capsule moves together, the old focused capsule shrinks out of focus, the new focused capsule expands into focus, and distant capsules fade according to their `y` position relative to the viewport center.

## Current Context

- `services/WindowHintService.qml` builds the active workspace hint snapshot and exposes `activeHint`, `hintHeld`, and `hintVisible`.
- `modules/workspace-hint/WorkspaceHintWindow.qml` currently renders exactly three capsules: previous, active, and next.
- `modules/workspace-hint/WorkspaceHintCapsule.qml` already owns capsule morphing primitives such as width transitions, spring-driven `y`, clipped content, and focused vs neighbor visual states.
- The current implementation is slot-based, not scroll-based, so it cannot express "all capsules shift upward while the camera stays locked".

## Goals

- Keep the window hint camera locked to the visual center of the workspace hint area.
- Instantiate all workspace capsules for the full duration of `mod` hold.
- Animate workspace changes as continuous vertical scrolling rather than swapping three fixed slots.
- Support multi-step switching while held, such as `2 -> 4`, by visually stepping through `3`.
- Preserve the focused capsule handoff: the old focus keeps full content briefly while shrinking, and the incoming focus expands from compact to focused state.
- Drive far-capsule fading from `y` distance to the locked viewport center.
- Add a light spring rebound when attempting to move beyond the first or last workspace.

## Non-Goals

- Do not add fake workspaces or placeholder capsules beyond the real workspace list.
- Do not move animation orchestration into `WindowHintService`.
- Do not redesign the bar pull deformation or unrelated dockzone motion.

## Chosen Approach

Implement the effect in the view layer.

- `WindowHintService.qml` remains the source of truth for real workspace data and active workspace position.
- `WorkspaceHintWindow.qml` becomes the scroll viewport owner and animation coordinator.
- `WorkspaceHintCapsule.qml` becomes a reusable per-workspace renderer that derives its visual state from relative position to the animated focus.

This keeps data and motion responsibilities separate and matches the desired "scrolling window with fixed camera" behavior.

## Component Design

### `services/WindowHintService.qml`

Keep service responsibilities data-oriented.

Required outputs:

- `activeHint.workspaces`
- `activeHint.activeWorkspacePosition`
- active workspace `windows`
- current focused window title/icon

Add minimal transition context only:

- `previousActiveWorkspacePosition`
- `workspaceTransitionRevision`

`workspaceStepDirection` should be derived in the view layer from the previous and current active workspace positions instead of being stored in the service.

The service must not compute `y`, opacity, width, or capsule staging.

### `modules/workspace-hint/WorkspaceHintWindow.qml`

Promote this file into the owner of the coverflow viewport.

Responsibilities:

- keep all workspace capsule instances alive while `hintHeld` is true
- render capsules with a `Repeater` instead of three hard-coded slots
- maintain the continuous animated focus position
- queue multi-step transitions when the real active workspace changes by more than one step while held
- apply small visual overshoot and rebound at the first and last workspace boundaries
- keep existing delayed hide behavior so exit animation can finish after release

Core state inside the window:

- `visualFocusPosition`: continuous float used as the camera-aligned focus position
- `settledWorkspacePosition`: last completed visual focus workspace
- `targetWorkspacePosition`: next step target
- `pendingWorkspaceSteps`: queue for multi-step transitions
- transient rebound state for edge overshoot handling

### `modules/workspace-hint/WorkspaceHintCapsule.qml`

Turn the capsule into a generic workspace renderer.

Suggested inputs:

- `workspacePosition`
- `workspaceIndex`
- `relativeOffset`
- `cameraDistance`
- `focusProgress`
- `isFocusedVisual`
- `icons`
- `windows`
- current focused window title/icon for the active workspace content

The capsule should derive from those inputs:

- `y`
- `opacity`
- `width`
- active content expansion
- neighbor content compactness
- outgoing focus shrink and incoming focus expansion

## Motion Model

### Fixed Camera

The workspace hint viewport stays anchored at the same screen position. The list of capsules scrolls through that viewport. The user should perceive a stable camera and moving capsules, not a reflowing stack that reanchors around a different capsule.

### Continuous Focus Variable

Use one primary animated value:

- `visualFocusPosition`

Examples:

- workspace 2 focused: `visualFocusPosition = 1`
- switch to workspace 3: animate `1 -> 2`
- switch from workspace 2 to workspace 4 while held: animate `1 -> 2`, then `2 -> 3`

Every capsule computes:

- `relativeOffset = workspacePosition - visualFocusPosition`

This allows the entire stack to move with one consistent rule.

### Vertical Position

Each capsule `y` is derived from:

- a fixed center line inside the viewport
- `relativeOffset * capsulePitch`
- a small deterministic compression term for distant capsules so the stack stays readable without flattening near-focus motion

Result:

- `relativeOffset = 0`: capsule sits on the focus line
- `relativeOffset = -1`: one step above
- `relativeOffset = +1`: one step below

### Opacity by Y Distance

Opacity rules:

- focused capsule: fully opaque
- immediate previous and next capsules: fully opaque
- more distant capsules: fade continuously according to their `y` distance from the viewport center
- capsules near or beyond the viewport edges continue fading toward zero

This preserves the sense of an always-existing scrolling list while keeping local focus clear.

### Width and Content Handoff

The outgoing focused capsule and incoming focused capsule should overlap visually during the handoff.

Outgoing focused capsule:

- starts with active content visible
- begins shrinking width early in the transition
- gradually returns to neighbor presentation in the latter half

Incoming focused capsule:

- starts in compact neighbor presentation
- expands width as it approaches the center line
- gradually reveals focused window content after the midpoint of the transition

This should be driven by a continuous `focusProgress`, not a hard `active` boolean swap at one frame.

### Boundary Rebound

At the first or last workspace, further movement attempts should not create fake capsules.

Instead:

- allow a small temporary overshoot in the scroll direction
- spring the visual focus back to the legal edge

The rebound is visual only and must not alter the real workspace state.

## Input and Transition Queue

When the real active workspace changes while `mod` is held:

- compare the new active position with the visually settled position
- decompose the delta into single-step moves
- append those single steps into a queue
- run the queue sequentially

Example:

- real state updates from workspace 2 to workspace 4
- queue becomes `2 -> 3`, then `3 -> 4`

This ensures the effect always reads as a coverflow scroll rather than a teleport.

## Lifecycle Rules

While `hintHeld` is true:

- all real workspace capsule instances remain alive
- focus changes update only position, opacity, width, and content progression
- capsule identity must remain stable across transitions

When `hintHeld` becomes false:

- keep the existing delayed-hide pattern so data survives the exit animation
- prefer collapsing/fading the viewport as one continuous object instead of toggling three staged slots
- if a step transition is still active, allow it to settle cleanly before the final hide completes

## Testing Plan

Add `tests/qml/tst_workspace_hint.qml`.

Required coverage:

- when moving from workspace 2 to 3, `visualFocusPosition` changes continuously instead of swapping slots
- the old focused capsule shrinks while the new one expands
- when moving quickly from workspace 2 to 4, the window processes two sequential visual steps rather than one direct jump
- at the first or last workspace, extra movement triggers visual rebound and settles back to the legal boundary
- releasing `hintHeld` does not clear hint data before exit animation completes
- while held, the rendered capsule count matches the real workspace count rather than a fixed count of three

If the trigger script or trigger service needs adjustment for step queuing semantics, add matching regression coverage there as a separate test.

## Implementation Notes

- Reuse existing motion constants from `services/Motion.qml` where possible.
- Preserve the current glass capsule surface continuity: width, color, radius, opacity, and position changes must all animate.
- Keep major QML declarations commented in English per repository convention.
- Prefer adapting existing capsule geometry and content nodes over replacing them with separate focused/unfocused component trees.

## Main Files Affected

- `services/WindowHintService.qml`
- `modules/workspace-hint/WorkspaceHintWindow.qml`
- `modules/workspace-hint/WorkspaceHintCapsule.qml`
- `tests/qml/tst_workspace_hint.qml`

## Risks and Mitigations

- Risk: queue handling may fight live service refreshes if workspace data updates mid-animation.
  - Mitigation: separate real data updates from visual step progression and keep capsule identity stable by workspace position.
- Risk: all-workspace instantiation could expose clipping or hit-region issues outside the visible viewport.
  - Mitigation: keep a fixed viewport mask and compute hit region from the visible faded viewport bounds, not the full logical list.
- Risk: edge rebound can feel like a false workspace switch if overshoot is too large.
  - Mitigation: keep the overshoot small and shorter than a normal step transition.
