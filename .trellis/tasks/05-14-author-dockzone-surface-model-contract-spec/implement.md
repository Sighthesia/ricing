# Implement: Author DockzoneSurfaceModel Contract Spec

## Checklist

### Step 1: Restate accepted boundaries
- [ ] keep renderer-agnostic contract shape
- [ ] keep state-machine-driven semantics
- [ ] keep semantic defaults over hardcoded style constants
- [ ] keep mirrored ear defaults with explicit override escape hatch
- [ ] keep surface-local ownership

### Step 2: Write contract spec document
- [ ] create `contract-spec.md`
- [ ] include field groups and field table
- [ ] define type intent and required/optional semantics
- [ ] define canonical progress driver rules
- [ ] define default value strategy
- [ ] define forbidden core-contract fields

### Step 3: Write strict state transition table
- [ ] list each required transition row
- [ ] identify semantic inputs per transition
- [ ] identify active canonical drivers per transition
- [ ] identify derived results per transition

### Step 4: Review for implementation-readiness
- [ ] ensure the spec can feed a later code implementation directly
- [ ] ensure derived values are not accidentally promoted to source-of-truth fields

## Validation

- read `contract-spec.md` end-to-end for contradictions
- confirm the transition table distinguishes input vs derived values in every row
- confirm no renderer-specific shortcut leaked into the core contract
