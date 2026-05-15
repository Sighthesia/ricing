# Design: Specification-Style DockzoneSurfaceModel Contract

## Output Shape

The next contract artifact should be written as a specification document, not as a loose design memo.

Required sections:

1. field groups
2. field table
3. type definitions
4. required vs optional semantics
5. default value strategy
6. state transition table
7. canonical progress driver rules
8. derived-field rules
9. forbidden core-contract fields

## Why This Format

The architecture boundaries are already sufficiently converged:

- renderer-agnostic core contract
- state-machine-driven model
- visible body vs transparent container split
- mirrored ear defaults with override escape hatch
- surface-local ownership
- canonical progress drivers derived from state transitions

At this point, another concept note would only restate the same ideas. A specification-style artifact is the smallest useful next output because it can feed implementation directly.

## Expected Contract Content

### Field groups

The contract spec should cover these groups explicitly:

- identity
- structural state
- geometry inputs
- global motion inputs
- ear-local state
- content-region state
- optional renderer adapter derived values

### Type system expectations

The contract spec should define type intent, even if the final implementation language stays QML/JS-first.

Examples:

- enum-like string unions for structural state
- normalized `0..1` numbers for canonical progress drivers
- booleans only where semantic toggles are truly binary
- numeric dimensions separated into semantic inputs vs derived outputs

### Required vs optional

The spec should distinguish:

- always-required semantic fields
- optional fields only needed for advanced motion or local override
- fields forbidden from the core contract

## State-Transition Emphasis

The specification should be state-transition-first.

That means transition rows such as:

- `hidden -> entering`
- `entering -> attached`
- `attached -> floating`
- `floating -> attached`
- `attached -> exiting`
- `exiting -> hidden`

For each row, the spec should identify:

- which canonical progress drivers are active
- which fields are expected to derive from them
- which ear-local deltas may be applied without breaking global continuity

## Forbidden Drift

The contract spec should explicitly reject these as core fields:

- anchor margins
- raw `x/y/width/height` convenience values from one renderer
- current overlay-window local placement details
- `Canvas` path control points
- per-property animation tracks that only exist because of one temporary implementation

## Recommendation

The next task after this planning step should author the actual contract spec document itself, not revisit architecture boundaries again.
