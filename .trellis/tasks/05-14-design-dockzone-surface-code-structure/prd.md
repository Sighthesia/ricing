# Design first code structure for DockzoneSurfaceModel

## Goal

Define the first implementation-oriented code structure for `DockzoneSurfaceModel`, including where the model contract should live, which file owns derivation, and how the future surface owner should be split across QML/JS files.

## Confirmed Facts

- Prior tasks already produced a full `DockzoneSurfaceModel` contract specification.
- The contract is renderer-agnostic, state-machine-driven, surface-local, and built around a small set of canonical transition drivers.
- The future architecture should move body and ears back under one shared geometry owner.
- The model should not be stored directly in `BarLayoutService`; it belongs to a future surface-local owner layer.
- Current code already uses a mixed QML + JS pattern for shell layout and helper logic, so the first implementation structure needs to respect existing repo conventions.

## Requirements

- Define the first-pass file structure for introducing `DockzoneSurfaceModel` into code.
- Clarify which concerns belong in QML, which in JS helpers, and which remain in the existing shared service.
- Keep the design aligned with the future unified owner rather than the current overlay workaround.

## Acceptance Criteria

- [ ] The plan identifies the likely file boundaries for the first implementation.
- [ ] The plan explains ownership between service, surface-local owner, and helper logic.
- [ ] The plan is implementation-ready enough for a subsequent coding task.

## Out of Scope

- Implementing the code structure now.
- Refactoring the existing bar modules immediately.

## Open Question

- Should the first implementation introduce the contract and its derivation as a new surface-local QML owner backed by a small JS helper, or keep all model derivation inside one JS-oriented helper layer first?

## Decision

- Accepted boundary: the first implementation should use a surface-local QML owner backed by a small JS helper, not a JS-first ownership model.
- Accepted boundary: the first implementation should start with one focused QML owner file plus one JS helper file, rather than an aggressively split multi-file structure.
- Accepted boundary: the first implementation should place that owner/helper pair directly under `modules/bar/` before any later subdirectory extraction.
- Accepted boundary: interfaces should be designed generically for `left | center | right`, but the first implementation/validation path should prioritize the center dockzone as the minimal closed loop.
- Accepted boundary: `DockzoneSurfaceRoot.qml` should expose only high-level semantic inputs to callers rather than flattening the full contract into public properties.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
