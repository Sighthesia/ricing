# Overlay bottom ears without increasing bar height

## Goal

Keep the current enlarged bottom-ear visuals for the side dockzones, but stop increasing the bar's effective height just to make those ears visible.

## Confirmed Facts

- The current overflow workaround lives in `modules/bar/BarWindow.qml` as `earOverflow`, and `implicitHeight` is currently `Services.BarLayoutService.barHeight + earOverflow`.
- `modules/bar/BarContent.qml` keeps all three `BarSection` bodies pinned to `Services.BarLayoutService.barHeight`, so the extra window height exists only to make the bottom ears visible.
- `modules/bar/BarDockZoneBackground.qml` currently draws the bottom ears below the body with `y: root.bodyHeight`, which means they extend outside the body rectangle instead of overlapping within it.
- The current ear size is large: `earRadius: 24`, so any solution must handle a fairly visible decorative overflow.
- The user's desired behavior is that bottom ears should behave like an overlay effect rather than consuming or implying extra bar height.

## Requirements

- Preserve the current center / left / right dockzone visual language unless a layout change is strictly required for the overlay behavior.
- Remove the current behavior where `earOverflow` increases the bar window height as part of normal bar sizing.
- Change the bottom-ear layout strategy so the ears visually overlay inside the same `barHeight` window instead of reserving exclusive bar height.
- Keep the side dockzone body rectangles aligned to `Services.BarLayoutService.barHeight`.
- Avoid unrelated service-layer or layout-model changes.

## Decision

- Chosen approach: keep a single bar window and make the bottom ears render as an in-window overlay rather than adding a second overlay surface/window.

## Trade-off

- This keeps the structure small and avoids extra shell surfaces, but the bottom ears must visually overlap the existing bar area instead of extending below the window boundary.

## Acceptance Criteria

- [ ] Bar height no longer grows because of bottom-ear visibility.
- [ ] Bottom ears remain visible after the overflow workaround is removed or replaced.
- [ ] Left, center, and right dockzone body content still aligns to the intended `barHeight` body region.
- [ ] Center dockzone does not regress.
- [ ] Affected QML files pass `qmllint`.

## Out of Scope

- Reworking the bar layout model or widget registry.
- Redesigning ear shapes, sizes, or section content behavior beyond what is required for overlay layout.

## Open Question

- None.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
