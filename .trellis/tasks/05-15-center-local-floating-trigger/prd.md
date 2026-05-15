# Wire local floating trigger for center

## Goal

Replace the temporary center floating validation flag with a more formal but still local trigger source, so the center dockzone can enter `floating` through a real content-local interaction intent without introducing a new global service or broad interaction system.

## Confirmed Facts

- `modules/bar/BarContent.qml` currently owns a temporary `centerFloatingValidationIntent` boolean used only for the center path.
- `modules/bar/BarSection.qml` already maps center content presence plus `floatingValidationIntent` into `hidden | attached | floating`.
- `modules/bar/DockzoneSurfaceRoot.qml` and `modules/bar/DockzoneSurfaceModel.js` already support the floating contract path, including real owner-local `detachProgress` and `morphProgress`.
- The current codebase has no existing hover or pointer semantics on the center content path.
- `modules/bar/BarWidgetWrapper.qml` is the shared host around center widgets and is the narrowest shared content-layer boundary available for introducing a local interaction signal.
- `modules/bar/widgets/Placeholder.qml` currently exposes only a plain `Text` item, so it cannot surface local pointer intent by itself without either being wrapped or upgraded.
- The earlier floating task deliberately kept the trigger local to `BarContent` / `BarSection` and out of services.

## Requirements

- Keep the trigger local to the center content path.
- Avoid introducing a new shared global service or store.
- Preserve the existing center owner/model boundary.
- Preserve left/right paths unchanged.
- Replace the temporary validation flag with a more formal local trigger source.
- Prefer a shared wrapper-level trigger over a widget-specific one.

## Acceptance Criteria

- [ ] Center floating is triggered by a real local interaction intent rather than a hardcoded validation boolean alone.
- [ ] The trigger remains local in scope and does not become a new global service.
- [ ] Existing center `attached` baseline remains stable when the local trigger is inactive.
- [ ] Left/right legacy paths remain untouched.
- [ ] Affected files pass static validation.

## Out of Scope

- New global floating state service.
- Left/right migration.
- Full redesign of center widgets.
- Broad pointer/gesture framework across the whole bar.

## Decision

- The first formal local floating trigger should be implemented at the shared `BarWidgetWrapper.qml` layer, not inside a specific center widget.

## Open Questions

- None blocking planning.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
