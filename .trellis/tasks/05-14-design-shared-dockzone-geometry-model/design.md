# Design: State-Driven Shared Dockzone Geometry Model

## Conclusion

The shared dockzone model should be designed as a **geometry + state + transition-progress** model from the start.

Do not design it as a static bag of dimensions and try to bolt animation states onto it later.

## Why Static Geometry Is Not Enough

The user requirements already imply stateful behavior:

- body and ears move as one object
- ears inherit global body motion
- ears may locally detach, exit, or morph
- visible body height must remain stable even when the transparent container is larger

Those requirements cannot be expressed cleanly with only width/radius/offset values.

## Recommended Model Layers

### 1. Structural state

This tells the system what kind of object configuration it is in.

Recommended enum-like state:

- `attached`
- `floating`
- `hidden`
- `entering`
- `exiting`

### 2. Shared geometry state

These properties describe the stable geometry frame for the surface.

- `visibleBodyWidth`
- `visibleBodyHeight`
- `containerWidth`
- `containerHeight`
- `bodyRadius`
- `earRadius`
- `contentRegionX`
- `contentRegionY`
- `contentRegionWidth`
- `contentRegionHeight`

### 3. Shared global motion state

These properties must be inherited by both body and ears.

- `translateX`
- `translateY`
- `scale`
- `opacity`
- `colorProgress`
- `visibilityProgress`

### 4. Ear-specific local state

These properties let ears add local behavior without breaking overall continuity.

- `leftEarPresence`
- `rightEarPresence`
- `leftEarMorphProgress`
- `rightEarMorphProgress`
- `leftEarDetachProgress`
- `rightEarDetachProgress`
- `leftEarOffsetX`
- `leftEarOffsetY`
- `rightEarOffsetX`
- `rightEarOffsetY`

## Core Inheritance Rule

The model should enforce this mental equation:

```text
Final ear motion = shared global surface motion + ear local delta
```

This guarantees:

- body and ears always travel together at the coarse level
- ears may still have controlled local exit or detach behavior
- local ear animation never replaces global continuity

## Visible Body vs. Container

The model must explicitly separate:

- **visible body region**: where the user perceives the main bar body
- **transparent container region**: the larger area that gives ears and morph motion room to exist

This is crucial because future owner unification depends on the container being allowed to exceed visible body size.

## Recommended Data Shape

Example conceptual shape:

```text
DockzoneSurfaceModel
├── state
├── geometry
├── globalMotion
├── leftEar
└── rightEar
```

Where:

- `state` controls the structural mode
- `geometry` controls body/container/content-region layout
- `globalMotion` applies to the full surface
- `leftEar` / `rightEar` add local overrides and progress values

## Transition Semantics

### Attached → Floating

- body keeps global continuity
- ears inherit the same translation/scale/opacity changes
- ear-specific `DetachProgress` and `Presence` drive local retreat/disappearance

### Hidden → Entering

- surface uses one global entry motion
- ears inherit it automatically
- ear presence can lag slightly if desired, but only as a controlled local delta

### Visible style changes

- color/radius/blur/opacity transitions should flow through shared progress state instead of independent hard-coded per-part animations

## Why This Helps the Future Owner Refactor

When the model already carries state, geometry, and progress together:

- moving back to one shared geometry owner becomes mostly a rendering refactor
- animation semantics do not need to be reinvented during owner consolidation
- the rendering tree can be swapped while the motion model stays stable

## Recommendation

The next implementation-oriented task should not start by editing `Canvas` paths.

It should start by defining a concrete `DockzoneSurfaceModel` contract with:

- state enum
- geometry fields
- global motion fields
- per-ear local transition fields

Then later rendering code can consume that model from a unified owner.
