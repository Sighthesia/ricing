# Design: Migrate Side Dockzones into Unified Surface Ownership

## Goal

Move the left and right dockzones onto the same `DockzoneSurfaceRoot + DockzoneSurfaceModel` architecture as the center path, while removing the bottom-ear overlay workaround in the same task.

## Key Decision

This task may expand the main bar window into a larger transparent geometry container, while keeping the visible bar body height equal to `Services.BarLayoutService.barHeight`.

This is the enabling condition that makes unified side ownership possible without retaining `BarBottomEarWindow.qml`.

## Architecture

```text
BarWindow
   -> larger transparent geometry container when needed
BarContent
   -> left / center / right sections remain composed here
BarSection (all sections)
   -> unified owner path for left / center / right
DockzoneSurfaceRoot.qml
   -> section-aware semantic owner and render root
DockzoneSurfaceModel.js
   -> section-aware pure geometry / motion derivation
```

## Why This Is The Right Next Step

The center path has already validated:

- owner-local state ownership
- pure model derivation
- semantic `surfaceState`
- floating / detach / morph driver flow

The main architectural unknown now lives in the side sections:

- asymmetric edge geometry
- bottom ear ownership
- larger transparent container vs visible bar body distinction

If the side sections can migrate into the same owner/model path and still keep their current silhouette, the unified architecture is no longer just a center prototype.

## Boundaries

### `BarWindow.qml`

Responsibilities in this task:

- allow a transparent geometry container taller than the visible bar body when needed for side ears
- keep the visible bar content aligned to the original `barHeight` body region

It should not:

- redefine business state
- become the owner of dockzone geometry semantics

### `BarContent.qml`

Keeps composing the three sections.

May need minimal layout/container adjustments so sections can render within a taller transparent window while preserving their visible body alignment.

### `BarSection.qml`

Should stop special-casing center as the only owner-managed path.

Responsibilities:

- route left / center / right through `DockzoneSurfaceRoot.qml`
- preserve section-specific semantic mapping where needed
- avoid reintroducing legacy ownership for side sections

### `DockzoneSurfaceRoot.qml`

Becomes the unified dockzone owner for all sections.

Responsibilities in this task:

- render left and right side silhouettes, not just center
- keep body and ears under one shared owner tree
- absorb side bottom-ear ownership that currently lives in `BarBottomEarWindow.qml`

### `DockzoneSurfaceModel.js`

Remains pure and stateless.

Responsibilities in this task:

- derive section-aware geometry for `left | center | right`
- represent a larger transparent container separately from the visible body region
- derive enough adapter-level metrics for side ears and side body geometry

### `BarBottomEarWindow.qml`

Target outcome for this task:

- remove from active rendering flow
- retire once side unified rendering is in place

## Data Flow

```text
BarLayoutService
   -> section widgets / barHeight
BarWindow
   -> transparent geometry container height
BarContent
   -> section composition
BarSection
   -> section semantics
DockzoneSurfaceRoot
   -> unified render owner
DockzoneSurfaceModel
   -> section-aware geometry + motion derivation
```

## Geometry Strategy

The key distinction in this task is:

- visible bar body height stays `barHeight`
- transparent geometry container may be taller than `barHeight`

That allows side bottom ears to belong to the same owner tree without forcing the visible bar itself to become taller.

Recommended first-pass strategy:

- keep top anchoring stable
- increase transparent container height only as much as the side bottom ears require
- keep content region aligned to the visible body region, not the full transparent container

## Migration Strategy

1. Extend `DockzoneSurfaceModel.js` so side geometry can be derived by section.
2. Extend `DockzoneSurfaceRoot.qml` so it can render left and right silhouettes in the same owner tree.
3. Route left and right through the new owner in `BarSection.qml`.
4. Remove `BarBottomEarWindow.qml` from active composition.
5. Adjust `BarWindow.qml` / `BarContent.qml` container sizing only as much as needed to preserve visual alignment.

## Trade-offs

- Benefit: completes the architectural move from center-only prototype to unified dockzone ownership.
- Benefit: removes the multi-window ear workaround, improving long-term motion continuity.
- Benefit: aligns with the already-decided direction that overlay ears are transitional only.
- Cost: touches more files than the earlier center tasks.
- Cost: bar-window container sizing becomes slightly more complex.
- Cost: side geometry regressions are more likely than in center-only work.

## Compatibility Notes

- Visible bar body height should still read as unchanged.
- Center path should keep working through the same owner/model structure.
- Shared services should remain unchanged.

## Rollback Shape

- re-enable legacy side routing in `BarSection.qml`
- restore `BarBottomEarWindow.qml` to active composition
- collapse `BarWindow.qml` back to `implicitHeight: Services.BarLayoutService.barHeight`
