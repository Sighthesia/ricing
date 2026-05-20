# Design: Validate Center Floating Semantics via Explicit Local Input

## Goal

Implement the first real `floating` validation path for the center dockzone by adding an explicit local semantic input that can drive `attached <-> floating` transitions without introducing a new interaction system or a new shared service.

## Architecture

```text
BarContent
   -> local validation input for center floating intent
BarSection (center)
   -> maps content presence + floating intent into semantic surfaceState
DockzoneSurfaceRoot.qml
   -> owns animated stateTransition / detach / morph progress
DockzoneSurfaceModel.js
   -> pure derivation from semantic state + owner progress snapshot
```

## Why This Validation Path

The repository currently has no natural hover / drag / focus interaction source for `floating`.

So the smallest correct next step is:

- add a local explicit semantic input
- use it only to validate the contract and owner/model boundary
- avoid pretending this is final product interaction

This keeps the scope on motion semantics rather than inventing new UX prematurely.

## Boundaries

### `BarContent.qml`

Owns a temporary local validation input for center floating intent.

Responsibilities:

- expose a small boolean or semantic flag for the center floating validation path
- pass it only to the center `BarSection`

It should not:

- become a new global state owner
- expose full contract fields
- add user-facing hover / click behavior in this task

### `BarSection.qml`

Owns semantic mapping from:

- content presence
- local floating intent

into a center `surfaceState`.

Recommended first-pass mapping:

- no content -> `hidden`
- content and no floating intent -> `attached`
- content and floating intent -> `floating`

### `DockzoneSurfaceRoot.qml`

Keeps owning runtime progress state.

This task extends owner-local drivers to make these fields real for the center floating flow:

- `stateTransitionProgress`
- `detachProgress`
- `morphProgress`

`visibilityProgress` behavior from the earlier task remains intact.

### `DockzoneSurfaceModel.js`

Remains pure and stateless.

Responsibilities for this task:

- accept owner-supplied `detachProgress` and `morphProgress`
- derive floating-aware global motion and ear-local state from those inputs
- keep all outputs reproducible from semantic inputs + owner progress snapshot

## Data Flow

1. `BarContent.qml` provides a center floating validation flag.
2. `BarSection.qml` combines that flag with `sectionModel.length > 0`.
3. `BarSection.qml` emits semantic `surfaceState` for the center path.
4. `DockzoneSurfaceRoot.qml` reacts to `surfaceState` and animates canonical progress values.
5. `DockzoneSurfaceModel.js` builds a contract-shaped model from semantic state + progress values.
6. The center renderer consumes derived motion / ear-local values.

## Driver Policy

This task should make these drivers meaningfully active for the center floating flow:

- `stateTransitionProgress`
- `detachProgress`
- `morphProgress`

Recommended first-pass semantics:

- `attached`: `detachProgress = 0`, `morphProgress = 0`
- `floating`: both animate toward visible non-zero values
- returning to `attached`: both collapse back to `0`

The exact numeric targets can stay conservative. The goal is to prove semantic wiring, not finalize visual design.

## Rendering Strategy

Stable attached visuals should remain unchanged.

Floating should introduce a readable but minimal difference by reusing the existing center render tree through:

- slightly stronger global transform shift or scale change
- small ear-local offset and/or presence delta
- mild body/ear morph signaling derived from progress rather than a brand new renderer tree

Avoid a full geometry rewrite in this task.

## Trade-offs

- Benefit: validates the core `floating` contract path with minimal new public API.
- Benefit: keeps the owner/model boundary honest by making `detachProgress` and `morphProgress` real.
- Benefit: avoids coupling floating to temporary picker semantics.
- Cost: the trigger remains a validation input rather than a final user interaction.
- Cost: first-pass floating visuals should stay conservative to avoid overcommitting to a temporary design.

## Compatibility Notes

- Left/right legacy paths remain untouched.
- `BarLayoutService.qml` remains unchanged.
- Existing hidden/attached path behavior should continue to work.

## Rollback Shape

- remove the local floating validation input from `BarContent.qml` / `BarSection.qml`
- collapse center mapping back to `hidden | attached`
- return `detachProgress` and `morphProgress` to neutral values in the owner/model flow
