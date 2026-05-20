# Finalize DockzoneSurfaceRoot code structure design

## Goal

Consolidate the final first-pass code structure for `DockzoneSurfaceRoot.qml` and `DockzoneSurfaceModel.js` so a later implementation task can start without reopening architecture boundaries.

## Confirmed Facts

- A full `DockzoneSurfaceModel` contract specification already exists.
- The future unified surface architecture should keep body and ears under one shared owner.
- The first implementation should use a surface-local QML owner plus a small pure-function JS helper.
- That first pair should live directly under `modules/bar/`.
- Interfaces should be generic for `left | center | right`, while the first validation path should prioritize the center dockzone.
- `DockzoneSurfaceRoot.qml` should expose only high-level semantic inputs, not the full contract fields.
- `DockzoneSurfaceModel.js` should remain a pure-function helper, not a stateful mini-store.

## Requirements

- Consolidate prior decisions into one final design artifact for the first-pass code structure.
- Clarify file roles, ownership, public inputs, internal derivation flow, and center-first validation strategy.
- Keep the result implementation-ready for the next coding task.

## Acceptance Criteria

- [ ] The design identifies first-pass file locations and responsibilities.
- [ ] The design clarifies the public interface boundary for `DockzoneSurfaceRoot.qml`.
- [ ] The design clarifies the pure-function role of `DockzoneSurfaceModel.js`.
- [ ] The design is sufficient to start a focused implementation task next.

## Out of Scope

- Writing the implementation now.
- Reopening already settled architecture boundaries.

## Decision

- This task should produce a consolidated design artifact, not another open-ended architecture exploration.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
