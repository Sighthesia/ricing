# Design: Center Surface Visibility and Attachment Progress Drivers

## Goal

Add the first real state/progress ownership to `DockzoneSurfaceRoot.qml` for the center path only, limited to the visibility/attachment lifecycle:

- `hidden`
- `entering`
- `attached`
- `exiting`

This task should prove that the owner drives semantic state and canonical progress fields, while `DockzoneSurfaceModel.js` remains a pure derivation layer.

## Architecture

```text
BarSection (center)
   -> DockzoneSurfaceRoot.qml
      -> owns semantic state input + animated progress values
      -> calls DockzoneSurfaceModel.js with semantic inputs + progress snapshot
      -> renders center surface from derived metrics
```

## Boundaries

### `DockzoneSurfaceRoot.qml`

Owns:

- semantic state input for the center surface
- animated canonical driver values
- transition timing and state-to-progress coordination
- renderer-facing bindings that consume the derived model

Does not own:

- shell-wide layout state
- left/right dockzone transitions
- a shared service-level surface state store

### `DockzoneSurfaceModel.js`

Owns:

- pure normalization of semantic inputs
- contract-shaped model assembly
- derived renderer metrics from the model

Does not own:

- timers
- animation lifecycle
- mutable progress state
- transition orchestration

## Public Input Shape

`DockzoneSurfaceRoot.qml` should keep a small semantic API.

Required or existing inputs:

- `section`
- `screenName`
- `surfaceHeight`
- `contentWidth`
- `contentHeight`

New first-pass semantic input:

- `surfaceState`

No raw canonical progress props should be exposed publicly in this task.

## Data Flow

1. Parent provides `surfaceState`.
2. `DockzoneSurfaceRoot.qml` maps that target state into animated owner-local progress values.
3. The owner passes the current semantic state plus current driver snapshot into `DockzoneSurfaceModel.buildModel(...)`.
4. `DockzoneSurfaceModel.js` returns a contract-shaped model.
5. Renderer metrics derive visibility, opacity, scale, and translation baselines for the center surface.

## Transition Scope

### Included

- `hidden -> entering`
- `entering -> attached`
- `attached -> exiting`
- `exiting -> hidden`

### Deferred

- `attached -> floating`
- `floating -> attached`
- real detach behavior
- real morph behavior

For deferred transitions, canonical fields should remain structurally present with neutral values.

## Driver Policy

This task should make these drivers real for the center path:

- `visibilityProgress`
- `stateTransitionProgress`

These drivers stay neutral in this task:

- `morphProgress = 0`
- `detachProgress = 0`

Recommended motion policy:

- `hidden`: opacity `0`, slightly reduced scale, slight upward offset
- `entering`: animate toward attached baseline
- `attached`: opacity `1`, scale `1`, zero offset
- `exiting`: animate from attached baseline toward hidden baseline

This keeps the first motion readable without inventing side-ear-specific behavior too early.

## Rendering Strategy

Keep the current center Canvas path geometry unchanged in stable `attached` state.

Use root-level global motion for the entire surface so body and ears stay visually continuous:

- item opacity
- item scale
- item translation

This matches the contract rule that ears inherit global motion from the body.

## Compatibility Notes

- `BarSection.qml` should continue routing only the center path through `DockzoneSurfaceRoot.qml`.
- Left/right legacy paths remain untouched.
- `BarLayoutService.qml` remains unchanged.

## Trade-offs

- Benefit: smallest behavioral proof that the new owner/model split is not just structural.
- Benefit: avoids prematurely designing floating semantics before the center visibility lifecycle is stable.
- Cost: canonical contract is only partially exercised in this task.
- Cost: `surfaceState` may be locally seeded for now if no upstream state source exists yet.

## Rollback Shape

- Revert `DockzoneSurfaceRoot.qml` to static attached semantics.
- Keep `DockzoneSurfaceModel.js` contract-compatible even if progress animations are removed.
- Leave `BarSection.qml` routing unchanged unless the root API must be rolled back.
