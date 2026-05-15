# Design: First Code Structure for DockzoneSurfaceModel

## Accepted Boundary

The first implementation should introduce:

- a **surface-local QML owner**
- backed by a **small JS helper** for derivation and normalization

This keeps semantic ownership near the future unified surface while still allowing pure geometry math to stay outside dense QML bindings.

## Responsibility Split

### Surface-local QML owner

- owns the `DockzoneSurfaceModel` instance semantics
- owns state bindings and state transitions
- consumes upstream layout inputs from existing services
- exposes derived values to the eventual unified render tree

### JS helper

- owns pure geometry derivation logic
- normalizes semantic inputs into stable geometry fields
- computes renderer-agnostic derived values
- does not own lifecycle or structural state transitions

### Existing shared service

- continues to own shell-wide layout inputs only
- should not absorb surface-local animation state

## Why This Split

- It matches the long-term unified-owner architecture.
- It avoids turning the contract into a global service concern.
- It keeps geometry math testable and isolated without stripping semantic ownership out of QML.

## Pending Design Edge

The first pass should stay intentionally compact:

- one focused QML owner file
- one focused JS helper file

Why:

- it keeps ownership and semantic flow easy to verify
- it avoids premature fragmentation before the model is proven in code
- it leaves room to split later once the first unified owner is validated

## Pending Design Edge

The first owner/helper pair should live directly under `modules/bar/`.

Recommended initial files:

- `modules/bar/DockzoneSurfaceRoot.qml`
- `modules/bar/DockzoneSurfaceModel.js`

Why:

- it keeps the first implementation close to current bar composition files
- it minimizes initial integration friction with `BarWindow.qml`, `BarContent.qml`, and `BarSection.qml`
- it allows the model and owner semantics to be proven before introducing directory churn

## Validation Strategy

The interface should be section-generic from day one, but the first practical validation target should be the center dockzone.

Why:

- center has the simplest current attachment semantics
- it avoids mixing screen-edge complications with the first model validation pass
- once the center path proves the owner/model shape, left/right edge-specific ears can be layered on without redesigning the contract

## Public Interface Rule

`DockzoneSurfaceRoot.qml` should expose only high-level semantic inputs.

Recommended public inputs:

- `section`
- `screenName`
- `surfaceState`
- `layoutInputs` or equivalent compact upstream layout bundle
- optional state/transition intent inputs when a parent needs to request a mode change

It should **not** expose the full `DockzoneSurfaceModel` field set as public properties.

Why:

- it preserves the owner boundary
- it keeps the component API stable while the internal contract evolves
- it prevents callers from driving derived fields directly
