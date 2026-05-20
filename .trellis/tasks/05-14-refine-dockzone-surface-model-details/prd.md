# Refine DockzoneSurfaceModel contract details

## Goal

Refine `DockzoneSurfaceModel` into an implementation-ready contract shape: field groups, required vs optional semantics, animation-driving rules, and the minimal adapter boundary for future QML consumption.

## Confirmed Facts

- Prior tasks already established that body and ears should eventually return to one shared geometry owner.
- The shared model should be state-machine-driven from the beginning rather than a static geometry table.
- The contract should stay renderer-agnostic at the core data-shape level.
- The model must distinguish visible body height from the larger transparent geometry container.
- Ear motion should be expressed as shared global surface motion plus ear-local delta.
- A later QML implementation may need a small adapter layer, but renderer-specific anchor math should not define the core contract.

## Requirements

- Define how detailed the contract's animation-driving fields should be.
- Clarify required vs optional field groups.
- Clarify which values should be semantic inputs versus derived adapter outputs.
- Keep the contract suitable for future unified-owner implementation rather than the current temporary rendering structure.

## Acceptance Criteria

- [ ] The contract detail plan explains field-group granularity.
- [ ] The plan distinguishes direct animation drivers from derived geometry.
- [ ] The plan stays renderer-agnostic at the core level.
- [ ] The result is actionable for the next design step.

## Out of Scope

- Implementing the contract in code now.
- Finalizing concrete QML bindings now.

## Open Question

- None.

## Decision

- Accepted boundary: the core contract should prefer a small set of canonical transition progress drivers, with most animation-facing values derived from those drivers plus state.
- Accepted boundary: left and right ears should default to mirrored synchronized behavior, with explicit per-side override only when a task truly requires asymmetry.
- Accepted boundary: `DockzoneSurfaceModel` should belong to the future surface-local owner / surface root layer rather than be stored directly in `BarLayoutService`.
- Accepted boundary: canonical progress drivers should be state-transition-oriented first, not property-interpolation-oriented first.
- Accepted boundary: the next output should be a specification-style contract document, not another concept-only note.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
