# Design: Split Ear-Body Motion Rules from Global Style Transition Rules

## Decision

Use two project-local skills:

1. `glass-liquid-design`
   - owns dockzone, ear/body, attached-surface, and motion-continuity rules

2. a new style-transition skill
   - owns project-wide transition hygiene rules for visual variable changes

## Why Split Them

### `glass-liquid-design` should stay domain-specific

It already owns:

- motion contract
- attached island surfaces
- dockzone composition
- QML visual heuristics for shell surfaces

Ear/body animation unity is part of that same domain because it defines how a dockzone surface behaves as an object.

### Transition hygiene is broader than dockzones

Rules such as:

- color changes must transition
- blur changes must transition
- radius changes must transition
- opacity/scale/spacing/shadow changes must transition when perceptible

apply to far more than dockzones.

Those rules should therefore live in a separate skill that can be loaded for any style-adjustment task.

## Planned Skill Responsibilities

### `glass-liquid-design`

Add rules such as:

- ear is subordinate geometry of its dockzone body
- ear and body must read as one continuous object
- ear inherits the body's global motion: translation, scale, opacity, color-state, visibility-state
- ear may add local transitions such as exit, detach, or morph only if object continuity remains intact
- if unified large-scale motion is required, separate overlay-ear ownership is a transitional workaround rather than the final architecture

### New style-transition skill

Add rules such as:

- every perceptible visual variable change must transition unless there is an explicit reason not to
- required transition coverage includes color, opacity, blur, shadow, radius, spacing, position, scale, and relevant geometry properties
- avoid hard cuts in styling variables that the eye reads as object-state changes
- style adjustments should preserve continuity even when the object is not morphing structurally

## Naming Direction

Recommended new skill name:

- `visual-transition-rules`

Why:

- narrow enough to be discoverable
- broad enough to cover all style-variable transitions
- clearly distinct from the visual-language skill

## Documentation Shape

### Update existing skill

Edit:

- `.agents/skills/glass-liquid-design/SKILL.md`

### Create new skill

Add:

- `.agents/skills/visual-transition-rules/SKILL.md`

## Optional Discoverability Update

Because this repo does not currently maintain a local skill index table in a root `CLAUDE.md`, discoverability can remain skill-file based for now.

If future skill count grows, add a brief project-local skill index to `AGENTS.md`.
