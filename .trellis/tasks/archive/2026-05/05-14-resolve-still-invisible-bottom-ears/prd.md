# Resolve still-invisible bottom ears

## Goal

Make the left and right bottom ears actually visible by moving them out of the constrained single-window bar surface into a dedicated overlay rendering layer.

## Confirmed Facts

- The current single-window approach has already been tested with: in-window overlay positioning, elevated `z`, and native bottom-ear paths.
- Even after those changes, the bottom ears remain fully invisible in runtime behavior.
- `modules/bar/BarWindow.qml` currently keeps the main bar window height equal to `Services.BarLayoutService.barHeight`.
- `modules/bar/BarDockZoneBackground.qml` currently owns the ear geometry, but the bottom-ear branches are no longer a reliable place to render visible downward decorations inside the bar window.
- The user has approved abandoning the single-window overlay constraint in favor of a dedicated overlay surface/window for the bottom ears.

## Requirements

- Keep the main bar window height unchanged at `Services.BarLayoutService.barHeight`.
- Render the bottom-left and bottom-right ears in a dedicated overlay surface/window so they can be visible outside the main bar body.
- Preserve the current center dockzone behavior.
- Preserve left/right symmetry.
- Keep the existing top-ear behavior intact.
- Avoid unrelated service-layer or layout-model changes.

## Decision

- Chosen approach: introduce a dedicated overlay surface/window for the bottom ears instead of continuing to force them into the main bar window.

## Acceptance Criteria

- [ ] Bottom-left ear is visibly rendered.
- [ ] Bottom-right ear is visibly rendered.
- [ ] Main bar window height remains equal to `Services.BarLayoutService.barHeight`.
- [ ] Left/right symmetry remains intact.
- [ ] Center dockzone does not regress.
- [ ] Affected QML files pass `qmllint`.

## Out of Scope

- Reworking the bar layout model or service layer.
- Redesigning the top ears or center dockzone.

## Open Question

- None.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
