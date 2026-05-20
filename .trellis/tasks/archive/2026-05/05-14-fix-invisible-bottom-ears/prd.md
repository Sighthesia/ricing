# Fix invisible bottom dockzone ears

## Goal

Make the bottom ears of the left and right dockzones actually visible again without increasing the bar window height.

## Confirmed Facts

- `modules/bar/BarWindow.qml` currently uses `implicitHeight: Services.BarLayoutService.barHeight`, so there is no extra surface space below the bar body anymore.
- `modules/bar/BarDockZoneBackground.qml` currently tries to render bottom ears as in-window overlays by placing them at `y: root.bodyHeight - root.earRadius`.
- The bottom ears have already been moved above the body/content layer with `z: 2`, so the remaining invisibility is not explained by simple stacking order alone.
- The bottom ear canvases are still based on rotated quarter-circle paths; if the rotated path mostly falls outside the local canvas bounds, the ear can remain fully invisible even though the canvas item itself exists.
- The current enlarged ear size is `earRadius: 24`, so any in-window overlay solution must decide how much of the body area the ear is allowed to overlap.

## Requirements

- Keep a single bar window and do not reintroduce bar-height growth.
- Make both bottom ears visibly render.
- Preserve the existing left/right symmetry.
- Preserve the current center dockzone behavior.
- Avoid unrelated service-layer or widget-layout changes.
- Prefer a light edge-attached overlap instead of letting the bottom ears cut deeply into the body area.

## Decision

- Chosen approach: keep the bottom ears lightly attached to the body edge and avoid a deep in-body overlap even if that requires a more careful path/position adjustment.

## Acceptance Criteria

- [ ] Bottom-left ear is visibly rendered.
- [ ] Bottom-right ear is visibly rendered.
- [ ] Bar window height remains equal to `Services.BarLayoutService.barHeight`.
- [ ] Left/right symmetry remains intact.
- [ ] Center dockzone does not regress.
- [ ] Affected QML files pass `qmllint`.

## Out of Scope

- Reworking the bar layout model or service layer.
- Introducing an extra overlay window.

## Open Question

- None.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
