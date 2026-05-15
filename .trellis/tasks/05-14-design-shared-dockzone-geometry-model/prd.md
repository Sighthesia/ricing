# Design shared dockzone geometry parameter model

## Goal

Define a shared dockzone geometry model that is state-machine-driven from the start, so body and ears can animate as one continuous object without later reworking the model shape.

## Confirmed Facts

- Prior analysis already concluded that body and ears should eventually return to one shared geometry owner.
- The user has approved a larger transparent geometry container than the visible bar body.
- The user has also confirmed that ear and body must synchronize in global motion while still allowing ear-specific local exit or morph behavior.
- A static size/offset table would not be enough to express attached, floating, hidden, entering, and exiting behaviors cleanly.

## Requirements

- Design the shared dockzone geometry model as a state-machine-driven model rather than a static geometry struct.
- Cover geometry, visibility, motion inheritance, and local ear-specific transition progress in one coherent parameter model.
- Preserve the distinction between visible body region and larger transparent geometry container.
- Keep the design actionable for a later implementation task.

## Acceptance Criteria

- [ ] The model includes both geometry parameters and state/transition parameters.
- [ ] The design explains how ear and body stay globally synchronized while still allowing local ear transitions.
- [ ] The model keeps visible body height distinct from container height.
- [ ] The resulting direction is suitable for a future unified owner implementation.

## Out of Scope

- Implementing the model now.
- Reworking unrelated widget/service logic.

## Decision

- Accepted boundary: the shared geometry model should be state-machine-driven from the beginning, not introduced later as an afterthought.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
