# Author DockzoneSurfaceModel contract spec

## Goal

Produce the actual specification-style `DockzoneSurfaceModel` contract document so future implementation can consume it directly.

## Confirmed Facts

- Prior planning already established the renderer-agnostic, state-machine-driven boundary for the core contract.
- Visible body height and transparent container height must remain distinct concepts.
- Canonical progress drivers should be few, semantic, and state-transition-oriented.
- Left and right ears should default to mirrored synchronized behavior with explicit override only when needed.
- Ear-local fields should remain present in the contract shape at all times, with default values representing "no local override".
- The contract should remain surface-local and should not be collapsed into `BarLayoutService` ownership.

## Requirements

- Write the contract as a specification document rather than a concept note.
- Include field groups, field table, type intent, required/optional semantics, default strategy, transition table, canonical progress rules, derived-field rules, and forbidden core fields.
- Keep the contract implementation-ready without binding it to temporary renderer details.

## Acceptance Criteria

- [ ] The spec defines field groups and a stable contract shape.
- [ ] The spec makes ear-local fields always present with explicit neutral defaults.
- [ ] The spec distinguishes semantic inputs from derived adapter values.
- [ ] The spec is actionable for a future implementation task.

## Out of Scope

- Implementing the contract in code now.
- Designing the full adapter API in this step.

## Open Question

- None.

## Decision

- Accepted boundary: default values should prefer semantic defaults sourced from the future surface owner / config layer, with concrete numeric defaults used only for true neutral values such as zero offset or zero progress.
- Accepted boundary: the state transition table in the contract spec should explicitly distinguish semantic inputs from derived results for each transition.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
