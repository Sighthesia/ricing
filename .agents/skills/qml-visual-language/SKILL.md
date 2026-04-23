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

## Floating Shell Unification

Bar-derived popups, cards, menus, and expanded inner surfaces must read like one
`SuperIsland` family instead of multiple popup dialects.

### Required Surface Contract

- Prefer one shared shell language for launcher, settings, history, media, menus,
  notification cards, and SuperIsland inner cards.
- Treat the old floating-panel look as legacy. New work should start from the
  shared shell language, not from ad hoc `Rectangle` shells.
- Reuse one surface family across outer shell, inner cards, badges, and action
  rows unless a local exception is intentionally emphasized.
- If a component is visually derived from the bar or SuperIsland overlay, it
  should feel attached to that system even when technically implemented as a
  popup or detached window.

### Required Token Contract

- Put shared shell geometry, spacing, and alpha in `config/ThemeCards.qml`.
- Use the `shell*` token family for common outer shell behavior.
- Use `ThemeCards` card families such as compact, panel, notification, menu,
  and overlay-nav tokens before adding new feature-local literals.
- Keep feature-specific tokens only for business geometry that is truly local.
  Do not let launcher, settings, or control-center pages each redefine their own
  shell radius, border alpha, or padding language.

### Migration Rules

- When unifying an existing surface, change the shell first and preserve the
  service/state/overlay ownership if possible.
- Replace repeated local border/radius/fill rectangles with one shared shell
  base before attempting larger structural migration.
- Inner cards inside `modules/bar/superisland/*` should not quietly drift back
  to a generic popup style just because they live inside a larger shell.
- Small chips, badges, and action buttons matter. Once major shells are unified,
  those smaller surfaces become the most visible remaining inconsistency.

### Review Checklist For Floating Shells

- Does this popup/card/menu look like it belongs to the SuperIsland family?
- Are radius, border alpha, fill alpha, inset, and gap derived from shared
  tokens rather than local literals?
- Was the shell unified without moving unrelated ownership or behavior into a
  new place?
- After large surfaces were aligned, were the remaining small buttons, badges,
  and chips checked for drift as well?

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
- If the first reveal looks correct but later swaps collapse into whole-list motion, reset the reused `ListView` state before the next stagger and verify the outgoing layer is still retiring independently.
- When matching the pace of settings or launcher lists, reuse the same base delay and step cadence family rather than making one page feel noticeably faster than another.
- For notification history and similar history panels, use the same open/switch stagger family as settings pages: panel shell opens first, then visible rows enter with a shared base delay and step cadence.
- For first open of a paged list, keep the reveal on one owner path only; if the page-level enter already owns the reveal, model refreshes must not replay row stagger while the first reveal is still pending.
- For paged list or deck surfaces, the page itself owns the first-open reveal contract: delegates may exist early, but they do not visually enter until the page releases the reveal window.
- Scrolling a list must animate both directions: items entering the viewport stagger in, and items leaving the viewport stagger out.
- Scroll-driven stagger must stay bounded to the visible window. Do not create unbounded delays from total model size.
- Increase list-item travel and cadence enough that the stagger reads clearly at normal shell speeds; avoid effects so subtle they disappear during scroll.
- For repeated notification cards or similar popup stacks, the list owner must assign stagger delays from visual order. Do not rely on a shell refactor preserving the old stagger implicitly.
- If a delegate still has its own enter/exit animation, preserve that delegate-owned motion and let the parent only supply timing slots such as `enterDelay` or `exitDelay`.

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

## SuperIsland Semantic Ownership Map

Use this map when a change spans `SuperIslandWidget.qml`, `IslandWindowHintCard.qml`, and attached shell helpers.

### Root Elements

- `modules/bar/widgets/SuperIslandWidget.qml`: the bar host root `Item`.
- `modules/bar/superisland/IslandWindowHintCard.qml`: the window-hint presentation root `Item`.
- `modules/bar/AttachedExpansionShell.qml`: the attached-shell geometry root `Item` when that shell is active.

### Width Ownership

- The bar reservation width is owned by `SuperIslandWidget.qml` through its exported `layoutMeasurementWidth` and `implicitWidth`.
- `BarWidgetWrapper` measures the root export, not the inner title row.
- `IslandWindowHintCard.qml` only owns the internal hint layout width for the active presentation branch.

### Visual Body Ownership

- The visible bar-position SuperIsland body is `_pillClip` with `_pillBg` inside `SuperIslandWidget.qml`.
- The lower workspace/clock rectangle in `bar-expanded-detached` is `IslandWindowHintCard.qml`'s `_barExpandedDetachedLayout` and its background `Rectangle`.
- The title capsule strip in `bar-expanded-main` is `IslandWindowHintCard.qml`'s `_barExpandedMainLayout` and the `Row` inside it.

### Important Clarification

- The bar-position SuperIsland is not physically moved into the workspace rectangle.
- Only the window-hint content is rehomed into a detached lower presentation while the host root remains in the bar and keeps owning the exported width contract.

### Debug Rule

- If the title row background looks wrong, fix `IslandWindowHintCard.qml`.
- If the bar still reserves the wrong width, fix `SuperIslandWidget.qml`'s exported width contract first.

## References

- `modules/bar/widgets/SuperIslandWidget.qml`
- `modules/bar/superisland/ExpandedPanelDeck.qml`
- `modules/bar/superisland/IslandWindowHintCard.qml`
