# Migrate side dockzones to unified surface architecture

## Goal

Extend the validated center `DockzoneSurfaceRoot + DockzoneSurfaceModel` architecture to the left and right dockzones, so all dockzone sections share the same owner/model state path instead of keeping side sections on the legacy renderer.

## Confirmed Facts

- `modules/bar/BarSection.qml` already routes the center path through `DockzoneSurfaceRoot.qml`, while left/right still use the legacy `BarDockZoneBackground.qml` path.
- `modules/bar/BarDockZoneBackground.qml` still owns all current side body and top-ear shape drawing.
- `modules/bar/BarBottomEarWindow.qml` still renders side bottom ears in dedicated overlay windows as a transitional workaround.
- The project has already validated owner-local state, semantic `surfaceState`, and floating/detach/morph progress on the center path.
- The side dockzones carry geometry complexity the center path does not: asymmetric bottom corner treatment plus bottom-ear overlay behavior.
- The previous design direction explicitly treated overlay-ear ownership as a transitional workaround rather than the final architecture.
- `BarWindow.qml` still keeps the main bar window height pinned to `Services.BarLayoutService.barHeight`, which constrains any attempt to fully absorb bottom ears into the same window without a larger geometry strategy change.

## Requirements

- Migrate left/right dockzones onto the unified owner/model architecture.
- Preserve the current visible side silhouettes closely enough to avoid obvious regressions.
- Keep the migration incremental rather than rewriting the whole renderer tree at once.
- Avoid moving dockzone state ownership into shared services.

## Acceptance Criteria

- [ ] Left/right no longer depend on `BarDockZoneBackground.qml` as their primary state/render owner.
- [ ] Left/right consume `DockzoneSurfaceRoot.qml` / `DockzoneSurfaceModel.js` through the same owner/model boundary as center.
- [ ] Existing side visual behavior remains broadly intact.
- [ ] Affected files pass static validation.

## Out of Scope

- Full redesign of bar window sizing policy unless needed by the chosen migration strategy.
- Final polish of all floating side geometry.
- Unrelated widget or service refactors.

## Decision

- This task should remove the `BarBottomEarWindow.qml` overlay workaround in the same step as side migration.
- To make that possible, the main bar window may use a larger transparent geometry container while the visible bar body still remains aligned to `Services.BarLayoutService.barHeight`.

## Open Questions

- None blocking planning.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
