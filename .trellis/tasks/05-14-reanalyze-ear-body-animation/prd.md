# Reanalyze unified ear-body animation architecture

## Goal

Re-evaluate the current bar ear architecture so future ear and body animations can feel like one continuous object during large-scale scaling, translation, morphing, and visibility changes.

## Confirmed Facts

- Top ears currently render inside `modules/bar/BarDockZoneBackground.qml` as part of the main dockzone background item tree.
- Bottom ears currently render from `modules/bar/BarBottomEarWindow.qml` as separate overlay `PanelWindow` instances per screen.
- The current overlay-window approach solved bottom-ear visibility, but it split ear rendering across separate geometry owners and separate windows.
- Quickshell supports multiple transparent `PanelWindow` surfaces per screen, and this repo already uses that pattern for other overlays.
- Cross-window animation coordination is mechanically harder than animating one shared QML item tree because position, scale, opacity, and timing must stay synchronized across multiple surfaces.
- If ear and body must read as one continuously deforming object, shared geometry ownership is a stronger foundation than separate overlay windows.

## Requirements

- Explain how to optimize the architecture so ear and body can animate together more uniformly in the future.
- Focus on architectural direction and trade-offs, not immediate implementation.
- Identify which current structural choices help visibility but hurt animation coherence.
- Identify what should become shared geometry state if future animation quality is prioritized.
- Clarify whether the current overlay-window solution should remain a final architecture or be treated as a transitional workaround.

## Acceptance Criteria

- [ ] The analysis clearly explains why the current split between body and bottom-ear windows helps or hurts unified animation.
- [ ] The recommended direction makes the trade-off between short-term convenience and long-term animation coherence explicit.
- [ ] The next architectural step is actionable for a later implementation task.

## Out of Scope

- Implementing the refactor now.
- Reworking unrelated bar layout or service logic.

## Open Question

- None.

## Decision

- Accepted boundary: if ear and body need truly unified large-scale animation, the architecture may replace the current bottom-ear overlay-window solution with a single shared geometry owner.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
