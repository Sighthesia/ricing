# Design: DockzoneSurfaceModel Contract Spec Artifact

## Output Goal

This task should produce the first full specification-style contract document for `DockzoneSurfaceModel`.

Recommended artifact path:

- `contract-spec.md`

## Required Sections

The contract document should include:

1. purpose and scope
2. field groups
3. field table
4. type intent
5. required vs optional semantics
6. default value strategy
7. canonical progress driver rules
8. state transition table
9. derived-field rules
10. forbidden core-contract fields

## Strictness Level

The state transition table should not be a loose narrative.

For every transition row, it should explicitly separate:

- **semantic inputs**
- **active canonical drivers**
- **derived results**

This prevents later implementations from driving derived fields directly as if they were source-of-truth inputs.

## Transition Rows To Cover

At minimum:

- `hidden -> entering`
- `entering -> attached`
- `attached -> floating`
- `floating -> attached`
- `attached -> exiting`
- `exiting -> hidden`

## Contract Discipline

The document should preserve all previously accepted boundaries:

- renderer-agnostic core contract
- state-machine-driven model
- semantic defaults over hardcoded visual constants
- mirrored ear behavior by default
- always-present ear-local fields with neutral defaults
- surface-local ownership
- state-transition-oriented canonical progress drivers

## Outcome

If this document is written correctly, the next implementation task should be able to:

- define the actual model shape in code
- build a surface-local owner around it
- add a small renderer adapter later without changing the core contract
