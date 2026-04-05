---
name: qml-visual-language
description: Use when defining or enforcing visual identity, motion language, and cross-component consistency for DymicShell UI, especially SuperIsland expanded-area components.
---

# Visual Language

Define and enforce a consistent UI language across motion, structure, and surface treatment.

## Use For

- Establishing a design language for a feature area or subsystem.
- Keeping multiple components visually consistent across open/close, reveal, and handoff states.
- Documenting the required shared look and motion for SuperIsland expanded-area components.
- Reviewing whether a new component fits the existing visual language instead of inventing its own.

## Core Principles

- Shared surfaces should read as one continuous system, not stacked widgets.
- Motion must feel like part of the same family across related components.
- Structural hierarchy, pulse, opacity, and spacing should reinforce the same intent.
- A component can have local emphasis, but it must not break the shared identity.

## Paged UI Language

Any DymicShell UI that has a page concept must use one shared page-switch motion language instead of inventing page-local transitions.

### Required Page-Switch Contract

- Opening a paged panel may animate both header controls and page body as one staged reveal.
- Switching between pages must not stagger the page-switch control itself if that would interfere with click timing or state readability.
- Switching pages must animate in two phases: current page exits first, then the next page enters.
- Page containers and page backgrounds must visibly fade during exit; do not leave the shell body static while only inner content moves.
- Page exit timing must stay bounded. If a page contains many repeated delegates, compress all visible exits into one fixed switch window instead of letting the delay grow with item count.
- Repeated page content such as notification cards, settings groups, or launcher results should stagger as a coordinated field, not as isolated one-off effects.

### Use This For

- SuperIsland expanded pages.
- Settings panels with sidebar or tab navigation.
- Launchers, notification centers, and any future deck, stack, or segmented page containers.

### Review Checklist For Paged UI

- Does the current page visibly exit before the next page appears?
- Does the page-switch control remain stable and clickable during retargeting?
- Does the page background participate in exit instead of lingering fully opaque?
- If the page shows a list, do all visible items animate within the switch window rather than only the last few?

## SuperIsland Expanded Area Language

The SuperIsland expanded area has a single design language that all components under `modules/bar/superisland/*` must follow.

### Required Visual Contract

- Use the same throw/catch story for all expanded-area transitions.
- Keep `window-hint`, launcher pages, settings pages, notifications pages, and clock/header content inside the same motion family.
- Preserve the shell as the dominant visual shape; child components must not override the host choreography.
- Content fade is secondary to shell motion.
- The handoff between `window-hint` and the expanded deck must feel seamless.

### Required Component Behavior

- Every new expanded-area component must inherit the shared reveal/collapse language.
- Do not introduce a separate open/close animation for a single page unless the exception is intentional and documented.
- Clock/header pulse, hint pulse, and page reveal should align with the same host timeline.
- If a component needs its own emphasis, it must happen inside the shared host motion, not instead of it.

### Visual Rules

- Prefer one continuous surface over visible nested containers.
- Keep width, height, y offset, and opacity changes coordinated.
- Use the same semantic surface and highlight colors across the region.
- Keep spacing, corner treatment, and shell continuity consistent from hint to deck.

### Review Checklist

- Does the component look like it belongs to SuperIsland's expanded region?
- Does its open/close motion match the shared throw/catch language?
- Does it preserve the shell's visual continuity during handoff?
- Does it avoid inventing a new motion dialect for a single page?

## References

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/ExpandedPanelDeck.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`
