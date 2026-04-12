# PRD

## Background
The workspace widget currently only shows windows from the current workspace. It also changes width abruptly when content size changes, which makes the UI feel jumpy.

## Goal
Fix the workspace widget so each workspace tab shows the windows that belong to that specific workspace, not just the currently active workspace. Add a smooth transition when the widget width changes.

## Requirements
- Each workspace tab must render the window list/previews for its own workspace.
- The current workspace should still behave correctly after the mapping fix.
- Width changes of the workspace widget should animate smoothly instead of snapping.
- Keep the change focused and compatible with existing DymicShell architecture and theme/timing tokens where appropriate.

## Non-Goals
- No redesign of the workspace widget visual language.
- No unrelated workspace service refactors unless required for the bug fix.

## Validation
- Verify the widget can display per-workspace windows correctly.
- Verify width changes use a visible transition during content changes.
- Run the repo's validated shell load check if implementation reaches a stable state.
