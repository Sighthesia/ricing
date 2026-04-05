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

## List Motion Language

Any repeated list content with clear rows or cards must use one shared stagger language for initial reveal, data refresh, and scroll-driven visibility changes.

### Required List Contract

- List items such as notification rows, launcher rows, clipboard rows, and similar repeated cards must reveal with stagger instead of all appearing at once.
- When a list's dataset is replaced or filtered, the old visible items must exit first and the new visible items must enter after the swap.
- The list owner must be able to take control of a batch enter animation so delegate-local viewport logic does not interrupt page-level or mode-switch choreography.
- If repeated list content should read as per-row stagger, animate each visible row from its own visible-order slot; do not move the whole list as one batch and call that stagger.
- If a fast model swap must keep visible exits while new content enters immediately, use a detached outgoing snapshot/layer for the retiring rows instead of relying on delegates that will be destroyed by `ListModel.clear()`.
- Scrolling a list must animate both directions: items entering the viewport stagger in, and items leaving the viewport stagger out.
- Scroll-driven stagger must stay bounded to the visible window. Do not create unbounded delays from total model size.
- Increase list-item travel and cadence enough that the stagger reads clearly at normal shell speeds; avoid effects so subtle they disappear during scroll.

### Use This For

- Notification history and notification centers.
- Launcher application results and clipboard results.
- Any `ListView`, `Flickable`, or repeated card stack where items visibly enter and leave the viewport.

### Review Checklist For Lists

- Do new items reveal with readable stagger on first open?
- Does filtering or mode switching avoid cutting off the new batch animation midway?
- When a list swaps datasets repeatedly, do visible rows still stagger individually on the second and later swaps rather than collapsing into one whole-list motion?
- Do both entering and leaving rows animate during scrolling?
- Is the stagger window based on visible rows rather than the full model length?

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

### Collapse Rules

- A detached `window-hint` must collapse with the same host-owned throw/catch and shrink-back story as the expanded deck.
- During `hint-exit`, keep the attached shell visually present until the host collapse geometry finishes; do not fade the surface midway through the shrink.
- Keep detached hint scale stable during collapse unless the host shell itself owns that scale curve for all expanded-area components.
- If the shell is still shrinking toward the bar center, inner content should remain visible long enough for users to read the return path.
- Clear detached hint content only after the attached collapse timeline completes, not when an earlier helper fade finishes.
- During the last collapse tail, the bridge shoulders must retire before they degenerate into thin floating ornaments under the pill.
- The last readable frame should simplify toward a clean pill silhouette, not preserve every decorative bridge detail to the mathematical end of the geometry animation.

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
- On collapse, can the user still see the surface shrink and travel back toward the bar instead of disappearing halfway?
- On collapse, do bridge decorations retire cleanly instead of turning into thin suspended shards near the pill?

## References

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/ExpandedPanelDeck.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`
