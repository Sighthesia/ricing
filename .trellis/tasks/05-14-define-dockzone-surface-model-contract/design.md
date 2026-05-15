# Design: DockzoneSurfaceModel Contract

## Conclusion

`DockzoneSurfaceModel` should be defined as a renderer-agnostic state-driven data contract first, not as a bundle of QML convenience bindings.

QML-facing derived values may exist later, but they should sit on top of the core contract rather than define it.

## Contract Layers

### 1. Identity and structural state

This layer describes what surface this is and what high-level state it is in.

Recommended core fields:

- `id`
- `section`
- `surfaceState`

Recommended `surfaceState` values:

- `attached`
- `floating`
- `hidden`
- `entering`
- `exiting`

## 2. Geometry inputs

These are authoritative inputs, not renderer-specific layout helpers.

- `visibleBodyWidth`
- `visibleBodyHeight`
- `containerWidth`
- `containerHeight`
- `bodyRadius`
- `earRadius`

## 3. Global motion inputs

These values apply to the whole surface and must be inherited by body and ears.

- `translateX`
- `translateY`
- `scale`
- `opacity`
- `colorProgress`
- `visibilityProgress`

## 4. Ear-local state

These values describe controlled local deviations that still sit on top of global surface motion.

### Left ear

- `leftEarPresence`
- `leftEarMorphProgress`
- `leftEarDetachProgress`
- `leftEarOffsetX`
- `leftEarOffsetY`

### Right ear

- `rightEarPresence`
- `rightEarMorphProgress`
- `rightEarDetachProgress`
- `rightEarOffsetX`
- `rightEarOffsetY`

## 5. Content-region state

These values keep content aligned to the visible body rather than the full transparent container.

- `contentRegionX`
- `contentRegionY`
- `contentRegionWidth`
- `contentRegionHeight`

## Ownership Boundaries

### Source-of-truth inputs

These should be owned by the shared surface model layer or the future unified surface owner, not by individual `Canvas` blocks:

- structural state
- geometry inputs
- global motion inputs
- per-ear local progress values

### Renderer-derived values

These should not be treated as core contract fields unless proven stable across renderers:

- anchor margins
- raw `Canvas` positions
- local path control points tied to one implementation
- item-specific `x/y/width/height` helper math

Those values belong in render adapters, not in the core contract.

## Input vs. Derived Field Rule

### Core contract fields

Keep in the core contract only fields that describe:

- semantic state
- stable geometry meaning
- shared motion meaning
- ear-local semantic deltas

### Derived fields

Allow only a small number of optional derived fields for a first-pass QML adapter, such as:

- `bodyRect`
- `contentRect`
- `leftEarAnchor`
- `rightEarAnchor`

These must be clearly marked as adapter-level derived values, not semantic inputs.

## Transition Semantics

The contract should preserve this rule:

```text
finalEarTransform = globalSurfaceTransform + localEarDelta
```

This means:

- body and ears always share the same coarse movement
- ear-local effects cannot replace global continuity
- state transitions remain readable as one object changing state

## Why Renderer-Agnostic Matters

If the contract encodes today's QML layout shortcuts too early:

- the future unified owner refactor will inherit temporary implementation details
- changing the rendering strategy will require contract churn
- state logic and renderer math will become entangled

Keeping the contract renderer-agnostic ensures the rendering tree can evolve while the motion/geometry semantics remain stable.

## Recommended Next Step

The next planning task after this one should define:

1. exact type shapes for each field group
2. which fields are required vs optional
3. which values are animated directly vs derived from a single progress value
4. a minimal QML adapter layer that maps the contract into the first unified owner implementation
