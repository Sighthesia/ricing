---
name: visual-transition-rules
description: "Load when adjusting QML visual styles, colors, radii, opacity, blur, shadows, spacing, scale, or related presentation variables. Enforces project-wide transition rules for perceptible style changes."
---

# Visual Transition Rules

Use this skill whenever adjusting visible styling in QML, even if the task is not changing structure.

## Core Rule

Every perceptible visual variable change must transition unless there is an explicit reason not to.

## Required Transition Coverage

When a user can perceive the change, provide transition behavior for:

- color
- opacity
- blur
- shadow
- radius
- border intensity
- spacing
- position
- scale
- geometry values that visually reshape the object

## Project-Level Constraints

- Do not hard-cut color-state changes that read as object state changes.
- Do not toggle styling variables instantly if the result feels like a visual teleport.
- Prefer one continuous transition chain over several unrelated staggered style snaps.
- Keep transition timing coherent across related properties so the object still reads as one object.
- If a property must change instantly for technical reasons, keep the perceptual change hidden or justified.

## Good Default Questions

Before finalizing a style change, ask:

- Will the user perceive this property change?
- If yes, what is the transition path?
- Does this transition keep the object feeling continuous?
- Is this property changing in sync with the other properties that define the same object?

## Anti-Patterns

Avoid:

- instant color swaps on visible surfaces
- radius jumps with no transition
- opacity cuts with no coordinated state change
- blur appearing or disappearing abruptly
- spacing or scale changes that cause hard visual pops
- animating one related property while hard-cutting the rest
