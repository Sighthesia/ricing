# Implement first DockzoneSurfaceRoot center path

## Goal

Introduce the first implementation of `DockzoneSurfaceRoot.qml` and `DockzoneSurfaceModel.js`, and wire them into the center dockzone path as the smallest end-to-end validation of the new surface-local owner model.

## Confirmed Facts

- A complete `DockzoneSurfaceModel` contract spec already exists under `05-14-author-dockzone-surface-model-contract-spec/contract-spec.md`.
- The finalized first-pass code structure already recommends two new files under `modules/bar/`: `DockzoneSurfaceRoot.qml` and `DockzoneSurfaceModel.js`.
- `DockzoneSurfaceRoot.qml` should expose only high-level semantic inputs and hold surface-local state.
- `DockzoneSurfaceModel.js` should stay pure and stateless, providing normalization and derivation only.
- The first validation path should prioritize the center dockzone because it avoids left/right edge-ear complexity while proving the owner/model boundary.
- `BarLayoutService.qml` should remain the source of shell-wide layout inputs only; it should not absorb surface-local animation state.

## Requirements

- Create `modules/bar/DockzoneSurfaceRoot.qml` as the first surface-local owner.
- Create `modules/bar/DockzoneSurfaceModel.js` as the pure derivation helper.
- Integrate the new owner into the center dockzone rendering path first.
- Preserve current center dockzone visual behavior as closely as possible while switching ownership.
- Avoid expanding this task into left/right dockzone migration.

## Acceptance Criteria

- [ ] `DockzoneSurfaceRoot.qml` exists and consumes high-level semantic inputs.
- [ ] `DockzoneSurfaceModel.js` exists and stays pure/stateless.
- [ ] The center dockzone path uses the new owner/model flow.
- [ ] Existing left/right paths are not prematurely migrated.
- [ ] Affected QML / JS files pass `qmllint` where applicable.

## Out of Scope

- Full left/right dockzone migration.
- Retiring `BarBottomEarWindow.qml`.
- Implementing the final unified body+ears render tree in one step.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- This is the first implementation validation of the contract/owner split, not the full dockzone refactor.
