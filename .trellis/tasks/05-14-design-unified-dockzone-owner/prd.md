# Design unified dockzone geometry owner

## Goal

Define the target architecture for a unified dockzone geometry owner so body and ears can animate as one continuous object.

## Confirmed Facts

- The current implementation split ownership between `modules/bar/BarDockZoneBackground.qml` and `modules/bar/BarBottomEarWindow.qml`.
- That split improved ear visibility but weakens unified animation because ear/body motion is no longer driven from one transform tree.
- The user has approved a future architecture where the transparent geometry container may be larger than the visible bar body.
- The visible bar height and the geometry container height do not need to remain identical, as long as the visual body still reads at the intended height.

## Requirements

- Recommend a final architecture that unifies body and ears under one geometry owner.
- Assume the geometry container may be larger than the visible bar body.
- Preserve the ability to keep the visible bar body height visually stable.
- Clarify which shared parameters should drive all ear/body layout and animation.
- Focus on design direction, not immediate implementation.

## Acceptance Criteria

- [ ] The design explains how to unify body and ear rendering ownership.
- [ ] The design explains how container height can exceed visible bar height without breaking the intended visual body size.
- [ ] The design identifies shared geometry and animation parameters.
- [ ] The design is actionable for a later implementation task.

## Out of Scope

- Implementing the refactor now.
- Reworking unrelated widget/service logic.

## Decision

- Accepted boundary: the future dockzone owner may use a larger transparent geometry container than the visible bar body, so ear/body animation can stay unified.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
