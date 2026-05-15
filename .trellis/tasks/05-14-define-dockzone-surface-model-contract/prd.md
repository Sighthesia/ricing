# Define DockzoneSurfaceModel contract

## Goal

Define a concrete `DockzoneSurfaceModel` contract that future unified dockzone rendering can consume without redesigning the state/geometry model again.

## Confirmed Facts

- Prior planning already established that body and ears should ultimately return to one shared geometry owner.
- The shared model must be state-machine-driven from the start rather than a static geometry table.
- The model must distinguish visible body height from the larger transparent geometry container.
- Ear motion should equal shared global surface motion plus ear-local delta, not a fully separate animation system.
- Current code is QML/Quickshell-based, but this contract is meant to outlive the current split between `BarDockZoneBackground.qml` and `BarBottomEarWindow.qml`.

## Requirements

- Define the contract shape clearly enough for later implementation.
- Cover field names, ownership boundaries, derived fields, and state transition semantics.
- Keep the contract aligned with the future unified owner direction.
- Avoid binding the contract too tightly to the current temporary overlay-window workaround.

## Acceptance Criteria

- [ ] The contract distinguishes input fields from derived fields.
- [ ] The contract identifies ownership boundaries for state, geometry, and local ear deltas.
- [ ] The contract is suitable for future QML implementation without being overfit to current temporary rendering structure.
- [ ] The contract includes enough state information to drive attached/floating/hidden/entering/exiting behavior.

## Out of Scope

- Implementing the contract in code now.
- Reworking unrelated service or widget logic.

## Open Question

- None.

## Decision

- Accepted boundary: the contract should stay renderer-agnostic at the data-shape level, with only a small number of optional derived fields added later for first-pass QML adoption.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
