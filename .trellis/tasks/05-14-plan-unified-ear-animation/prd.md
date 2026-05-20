# Plan unified ear animation architecture

## Goal

Define how to evolve the current bar ear implementation so future large-scale scaling, translation, morphing, and visibility transitions stay visually unified and mechanically stable.

## Confirmed Facts

- Top ears currently live inside `modules/bar/BarDockZoneBackground.qml` as part of the main dockzone background item tree.
- Bottom ears currently live in `modules/bar/BarBottomEarWindow.qml` as separate overlay `PanelWindow` instances per screen.
- The current structure solved runtime visibility for bottom ears, but it split the ear system across multiple windows and multiple geometry owners.
- `shell.qml` already composes multiple top-level reusable windows, so adding or restructuring window modules is architecturally allowed in this project.
- Quickshell supports multiple transparent per-screen `PanelWindow` surfaces, but cross-window animation coordination is inherently more complex than animating one shared item tree.

## Requirements

- Explain how to improve animation consistency for future ear scaling, translation, morphing, and visibility changes.
- Focus on architectural options and trade-offs rather than immediate code implementation.
- Preserve compatibility with the current Quickshell/QML bar structure.
- Identify which parameters should become shared geometry state.
- Clarify when the current multi-window approach is acceptable and when it becomes a liability.

## Acceptance Criteria

- [ ] The recommended direction clearly states whether to keep multi-window ears or converge to a more unified rendering model.
- [ ] The plan explains how to keep ear geometry and motion parameters synchronized.
- [ ] The trade-off between implementation complexity and animation quality is made explicit.
- [ ] The answer is actionable for future implementation work.

## Out of Scope

- Implementing the refactor now.
- Reworking unrelated bar layout or widget service logic.

## Open Question

- Should future optimization prioritize animation quality above all else, even if that means replacing the current overlay-window solution?

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
