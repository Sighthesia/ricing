# Fix active window transition visibility

## Goal

Make the active window icon/title change visibly transition instead of switching instantly.

## Requirements

- Keep the existing active window widget structure in `modules/bar/widgets/ActiveWindow.qml`.
- Preserve the current active window title and icon behavior.
- Ensure title and icon changes are visibly animated even when the focused window changes quickly.
- Keep the widget compact and compatible with the existing bar layout.

## Acceptance Criteria

- [ ] Active window icon/title changes are visibly animated rather than instant.
- [ ] The widget still shows the correct focused title and icon after transitions complete.
- [ ] No new layout regressions are introduced in the bar.
- [ ] The widget remains stable when focus changes rapidly.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
