# DockzoneSurfaceModel Contract Specification

## Purpose

`DockzoneSurfaceModel` defines the renderer-agnostic, state-driven contract for a dockzone surface whose body and ears must animate as one continuous object.

This specification is intended to remain stable even if the rendering tree, QML structure, or window strategy changes.

## Scope

This contract covers:

- structural surface state
- semantic geometry inputs
- global surface motion inputs
- ear-local semantic deltas
- content-region alignment state
- canonical transition progress drivers

This contract does **not** cover:

- renderer-specific anchors or margins
- `Canvas` path data
- per-window placement details
- implementation-specific convenience bindings

## Contract Shape

```text
DockzoneSurfaceModel
├── identity
├── state
├── geometry
├── globalMotion
├── leftEar
├── rightEar
└── contentRegion
```

## Field Groups

### Identity

Describes the stable identity of the surface instance.

### State

Describes the current structural mode and state-transition progress.

### Geometry

Describes semantic body/container sizing, independent from renderer coordinates.

### Global Motion

Describes transform and visual-state values inherited by the full surface.

### Ear State

Describes ear-local semantic deltas layered on top of global motion.

### Content Region

Describes the visible body-aligned region used for content placement.

## Type Intent

- enum-like string values should be modeled as constrained string unions
- canonical progress values should be normalized numbers in the range `0..1`
- dimensions should be numeric semantic values, not raw renderer anchors
- booleans should be used only for true binary semantics, not as substitutes for progress

## Field Table

| Group | Field | Type Intent | Required | Default Strategy | Notes |
|---|---|---|---|---|---|
| identity | `id` | string | yes | provided by owner | stable surface identity |
| identity | `section` | string union: `left \| center \| right` | yes | provided by owner | semantic section, not renderer anchor |
| state | `surfaceState` | string union: `attached \| floating \| hidden \| entering \| exiting` | yes | provided by owner | structural mode |
| state | `visibilityProgress` | number `0..1` | yes | semantic default `1` for visible states, `0` for hidden | canonical visibility driver |
| state | `stateTransitionProgress` | number `0..1` | yes | semantic default `0` when no transition is active | canonical structural transition driver |
| state | `morphProgress` | number `0..1` | yes | `0` | canonical shape-morph driver |
| state | `detachProgress` | number `0..1` | yes | `0` | canonical ear-detach driver |
| geometry | `visibleBodyWidth` | number | yes | provided by owner / layout policy | visible surface body width |
| geometry | `visibleBodyHeight` | number | yes | resolved from bar-height policy | visible surface body height |
| geometry | `containerWidth` | number | yes | semantic default derived from body + ear envelope | transparent geometry container width |
| geometry | `containerHeight` | number | yes | semantic default derived from body + ear envelope | transparent geometry container height |
| geometry | `bodyRadius` | number | yes | semantic geometry baseline | visible body radius |
| geometry | `earRadius` | number | yes | semantic geometry baseline | shared ear radius baseline |
| globalMotion | `translateX` | number | yes | `0` | inherited by body and ears |
| globalMotion | `translateY` | number | yes | `0` | inherited by body and ears |
| globalMotion | `scale` | number | yes | `1` | inherited by body and ears |
| globalMotion | `opacity` | number `0..1` | yes | `1` | inherited by body and ears |
| globalMotion | `colorProgress` | number `0..1` | yes | `0` | semantic color-state progression |
| leftEar | `presence` | number `0..1` | yes | `1` for attached visible baseline | derived from state + overrides in many cases |
| leftEar | `morphProgress` | number `0..1` | yes | `0` | local delta layered on shared morph |
| leftEar | `detachProgress` | number `0..1` | yes | `0` | local delta layered on shared detach |
| leftEar | `offsetX` | number | yes | `0` | neutral means no local override |
| leftEar | `offsetY` | number | yes | `0` | neutral means no local override |
| rightEar | `presence` | number `0..1` | yes | mirrors left ear baseline | derived from state + overrides in many cases |
| rightEar | `morphProgress` | number `0..1` | yes | mirrors left ear baseline | local delta layered on shared morph |
| rightEar | `detachProgress` | number `0..1` | yes | mirrors left ear baseline | local delta layered on shared detach |
| rightEar | `offsetX` | number | yes | `0` | neutral means no local override |
| rightEar | `offsetY` | number | yes | `0` | neutral means no local override |
| contentRegion | `x` | number | yes | semantic default derived from visible body | content region origin within container space |
| contentRegion | `y` | number | yes | semantic default derived from visible body | aligns content to visible body, not full container |
| contentRegion | `width` | number | yes | semantic default derived from visible body | content placement width |
| contentRegion | `height` | number | yes | semantic default derived from visible body | content placement height |

## Required vs Optional Semantics

### Required Core Fields

All fields in the table above are required in the contract shape.

Reason:

- stable contract shape is preferred over sparse optional field trees
- ear-local fields should always exist, with neutral defaults representing "no local override"
- consumers should not need presence checks just to understand the model

### Optional Meaning, Not Optional Presence

Some fields may be semantically inactive in certain states, but they still exist.

Examples:

- `detachProgress = 0` means no detach behavior is active
- `offsetX = 0`, `offsetY = 0` mean no local ear displacement override is active
- `morphProgress = 0` means no morph delta is active

## Default Value Strategy

### Semantic defaults first

Prefer semantic defaults sourced from the future owner/config layer for values that depend on layout policy or visual baseline.

Examples:

- `visibleBodyHeight` → resolved from current bar-height policy
- `earRadius` → resolved from current dockzone geometry baseline
- `containerHeight` → derived from visible body + ear envelope policy

### Concrete neutral defaults only where truly neutral

Use hard defaults only for values that semantically mean "no effect":

- `translateX = 0`
- `translateY = 0`
- `scale = 1`
- `opacity = 1`
- `morphProgress = 0`
- `detachProgress = 0`
- `offsetX = 0`
- `offsetY = 0`

## Canonical Progress Driver Rules

The contract should prefer a small canonical set of normalized progress drivers:

- `visibilityProgress`
- `stateTransitionProgress`
- `morphProgress`
- `detachProgress`

Rules:

1. canonical drivers are semantic and state-transition-oriented
2. canonical drivers are normalized `0..1`
3. detailed renderer values should derive from canonical drivers rather than expand the core contract
4. per-ear progress fields are local deltas, not replacements for global continuity

## Ear Symmetry Rule

Left and right ears should default to mirrored synchronized behavior.

That means:

- both ears consume the same canonical progress semantics by default
- asymmetry is allowed only through explicit local override values
- the baseline expectation is one surface with paired subordinate geometry, not two unrelated sub-objects

## Core Inheritance Rule

The contract preserves this rule:

```text
finalEarMotion = globalSurfaceMotion + localEarDelta
```

Implications:

- body and ears always move together at the coarse level
- ears may apply local detach, retreat, or morph behavior
- local ear changes must never replace global object continuity

## State Transition Table

### `hidden -> entering`

- Semantic inputs:
  - `surfaceState = entering`
  - visible geometry baseline
  - canonical visibility target
- Active canonical drivers:
  - `visibilityProgress`
  - `stateTransitionProgress`
- Derived results:
  - surface opacity ramps from hidden baseline toward visible baseline
  - global surface motion may move from off-state to attached baseline
  - ear presence follows entering baseline unless a local delay policy is explicitly defined

### `entering -> attached`

- Semantic inputs:
  - `surfaceState = attached`
  - attached geometry baseline
- Active canonical drivers:
  - `stateTransitionProgress`
  - `visibilityProgress`
- Derived results:
  - geometry settles into attached baseline
  - content region aligns to stable visible body region
  - ear local deltas return to neutral defaults unless a feature says otherwise

### `attached -> floating`

- Semantic inputs:
  - `surfaceState = floating`
  - floating geometry target
  - optional ear detach policy
- Active canonical drivers:
  - `stateTransitionProgress`
  - `detachProgress`
  - `morphProgress`
- Derived results:
  - body transforms toward floating geometry target
  - ears inherit global translation/scale/opacity changes
  - ear detach/presence values derive from detach policy instead of being driven independently

### `floating -> attached`

- Semantic inputs:
  - `surfaceState = attached`
  - attached geometry target
- Active canonical drivers:
  - `stateTransitionProgress`
  - `detachProgress`
  - `morphProgress`
- Derived results:
  - body returns to attached geometry baseline
  - ear detach deltas collapse back toward neutral
  - content region returns to attached alignment baseline

### `attached -> exiting`

- Semantic inputs:
  - `surfaceState = exiting`
  - exit visibility policy
- Active canonical drivers:
  - `visibilityProgress`
  - `stateTransitionProgress`
  - optional `detachProgress` if ears retreat during exit
- Derived results:
  - opacity and transform move toward hidden baseline
  - ears remain globally synchronized while local ear retreat may be layered in
  - content region is no longer treated as stable target once hidden transition completes

### `exiting -> hidden`

- Semantic inputs:
  - `surfaceState = hidden`
- Active canonical drivers:
  - `visibilityProgress`
  - `stateTransitionProgress`
- Derived results:
  - all visible contributions collapse to hidden baseline
  - ear local delta fields return to neutral defaults
  - model remains structurally present, but in hidden semantics

## Derived Field Rules

Derived values are allowed, but they are adapter-level outputs, not semantic inputs.

Examples of acceptable derived values:

- `bodyRect`
- `contentRect`
- `leftEarAnchor`
- `rightEarAnchor`
- any renderer-facing envelope or clip helpers

Rules:

1. derived values must be reproducible from core fields
2. derived values must not become alternate sources of truth
3. derived values may differ between renderers without changing the core contract

## Forbidden Core-Contract Fields

These must not enter the core contract:

- anchor margins
- raw renderer `x/y/width/height` convenience fields tied to one item tree
- current overlay-window local placement details
- `Canvas` path control points
- renderer-specific clipping helpers
- per-property animation tracks created only for one temporary implementation

## Implementation Readiness Notes

This contract is ready to drive the next implementation-oriented step:

1. define the actual model type shape in QML/JS or another project-appropriate representation
2. create the future surface-local owner that produces the model
3. build a minimal render adapter that derives QML-facing geometry from the core contract

It is intentionally not yet an adapter API.
