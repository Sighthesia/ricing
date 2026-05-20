# Implement center surface progress drivers

## Goal

Make the new center `DockzoneSurfaceRoot` own real canonical state/progress drivers instead of static placeholder values, so the owner/model boundary becomes behaviorally meaningful and ready for later left/right migration.

## Confirmed Facts

- `modules/bar/DockzoneSurfaceRoot.qml` already exists as the center-only surface-local owner.
- `modules/bar/DockzoneSurfaceModel.js` already exposes a contract-shaped model, but all transition-related fields are static placeholders.
- `BarSection.qml` already routes only the `center` section through `DockzoneSurfaceRoot.qml`; left/right still use the legacy `BarDockZoneBackground.qml` path.
- `BarLayoutService.qml` currently owns shell-wide layout inputs only and should not absorb surface-local transition state.
- The contract spec already defines the canonical drivers: `visibilityProgress`, `stateTransitionProgress`, `morphProgress`, and `detachProgress`.
- The contract spec already defines semantic states `hidden`, `entering`, `attached`, `floating`, and `exiting` plus expected driver combinations per transition.
- The current codebase has no real dockzone state machine, no upstream driver source, and no existing bar-surface transition implementation to reuse.

## Requirements

- Implement real center-local progress ownership inside `DockzoneSurfaceRoot.qml`.
- Keep `DockzoneSurfaceModel.js` pure and stateless.
- Preserve the existing center visual shape when the surface is stably attached.
- Expose only high-level semantic inputs on `DockzoneSurfaceRoot.qml`; do not flatten the full model contract into public props.
- Do not move progress ownership into `BarLayoutService.qml`.
- Do not migrate left/right paths in this task unless a minimal compatibility touch is unavoidable.

## Acceptance Criteria

- [ ] `DockzoneSurfaceRoot.qml` owns non-static canonical progress values instead of hardcoded placeholders.
- [ ] `DockzoneSurfaceModel.js` consumes semantic inputs plus owner-supplied progress values, while staying pure.
- [ ] The center path can represent at least one real transition flow through semantic state plus progress changes.
- [ ] Stable `attached` center visuals remain effectively unchanged.
- [ ] Left/right legacy rendering remains intact.
- [ ] Affected QML and JS files pass static validation.

## Out of Scope

- Full left/right migration.
- Final unified body+ears renderer for all sections.
- Moving dockzone transition state into shared services.
- Building unrelated widget or layout features.

## Decision

- The first real driver scope is limited to center visibility/attachment transitions only.

## Open Questions

- None blocking planning.
