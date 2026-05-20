# Design: Final First-Pass Code Structure for DockzoneSurface

## Conclusion

The first implementation should introduce two new files directly under `modules/bar/`:

- `DockzoneSurfaceRoot.qml`
- `DockzoneSurfaceModel.js`

This pair is the smallest structure that respects the already-settled ownership boundaries while staying close to the current bar composition.

## File Layout

```text
modules/bar/
├── BarWindow.qml
├── BarContent.qml
├── BarSection.qml
├── DockzoneSurfaceRoot.qml        # new surface-local owner
└── DockzoneSurfaceModel.js        # new pure-function model helper
```

## Responsibilities

### `DockzoneSurfaceRoot.qml`

Role:

- surface-local semantic owner
- state holder and transition coordinator
- bridge from upstream layout inputs to the contract model
- eventual render root for unified body + ears

Public inputs should stay high-level:

- `section`
- `screenName`
- `surfaceState`
- `layoutInputs`
- optional transition intent inputs only if a parent explicitly needs them

It should not expose every `DockzoneSurfaceModel` field as public props.

Internal responsibilities:

- collect semantic inputs
- call `DockzoneSurfaceModel.js`
- hold the current surface-local state and progress drivers
- expose a stable model object or derived bindings to internal children

### `DockzoneSurfaceModel.js`

Role:

- pure-function derivation layer
- normalization of semantic inputs
- production of contract-shaped data and renderer-agnostic derived values

It should not:

- own lifecycle
- own state transitions
- store mutable runtime state
- behave like a mini store

Recommended helper responsibilities:

- `normalizeSurfaceInputs(...)`
- `buildSurfaceModel(...)`
- `deriveGeometry(...)`
- `deriveContentRegion(...)`
- `deriveEarLocalState(...)`

Function naming can still evolve, but the purity boundary should remain strict.

## Ownership Boundary

### Existing `BarLayoutService`

Keeps owning:

- shell-wide layout inputs
- bar height policy
- section/widget layout data

Does not own:

- surface-local transition state
- ear/body deformation contract
- local animation progress for a specific dockzone surface

### New surface-local owner

Owns:

- `DockzoneSurfaceModel` instance semantics
- surface-local structural state
- canonical progress driver values for that surface

## Data Flow

```text
BarLayoutService
   -> layoutInputs
DockzoneSurfaceRoot.qml
   -> normalize/build via DockzoneSurfaceModel.js
   -> surface model instance
   -> internal render tree / future unified body+ears
```

## Validation Strategy

The interface should be section-generic from day one.

The first practical validation target should be the **center dockzone**.

Why center first:

- simplest attachment semantics
- avoids edge-specific bottom-ear concerns during the first contract/owner validation
- proves the owner/model boundary before left/right asymmetry is layered in

After the center path is stable, the same owner contract can be extended to left/right with edge-specific ear geometry.

## Why This Is The Right First Pass

- minimal new file count
- no premature directory churn
- ownership remains readable
- helper remains pure
- future unified owner refactor is already aligned with this structure

## Anti-Patterns To Avoid

- putting `DockzoneSurfaceModel` into `BarLayoutService`
- making the JS helper stateful
- exposing the whole contract as public QML props
- designing the first pass around the current temporary overlay-ear workaround
- splitting the owner into many tiny files before the basic model/owner loop is proven

## Recommendation

The next implementation task should be framed as:

**Create `DockzoneSurfaceRoot.qml` and `DockzoneSurfaceModel.js`, wire them into the center dockzone path first, and validate the owner/model boundary before expanding to left/right surfaces.**
