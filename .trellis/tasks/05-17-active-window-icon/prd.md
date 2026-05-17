# Add active window icon and transitions

## Goal

Show the focused window's app icon in the bar's active window widget, and animate width/content transitions when the active window changes.

## Requirements

- Reuse `modules/bar/widgets/ActiveWindow.qml`.
- Display an app icon derived from `Services.NiriService.activeAppId` when available.
- Keep the active window title visible and preserve the existing `Desktop` fallback.
- Animate the widget width when the title changes size.
- Animate the icon and title on entry/exit instead of popping abruptly.
- Fall back gracefully when no focused window or icon is available.

## Acceptance Criteria

- [ ] The active window widget shows an app icon next to the focused window title.
- [ ] The widget still shows `Desktop` when no focused window title is available.
- [ ] The widget does not throw errors when the active app id is empty or has no icon.
- [ ] Width changes caused by active window changes transition smoothly.
- [ ] The icon and title fade or slide in/out instead of appearing instantly.
- [ ] The widget remains compact and fits in the existing bar layout without other layout changes.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` and `implement.md` before `task.py start`.
