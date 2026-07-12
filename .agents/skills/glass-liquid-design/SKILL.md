---
name: glass-liquid-design
description: "Apply the project's high-priority motion contract and Glass Liquid visual language for QML/Quickshell UI. Use when designing or modifying QML visual components, PanelWindow surfaces, popups, islands, overlays, layout transitions, animations, states, or interaction feedback."
---

# Glass Liquid Design

Use this skill whenever creating or modifying visible QML/Quickshell UI.

## Priority 1: Universal Motion Contract

These rules override visual styling preferences. Do not trade them away for a specific look.

- Prefer a single persistent visual instance over separate replacement elements.
- Preserve object continuity across states: the user should feel the same object moved, resized, expanded, collapsed, softened, or transformed.
- Animate every perceptible property change, including position, size, opacity, radius, color, blur, shadow, spacing, and scale.
- Avoid sudden appearance, sudden disappearance, hard layout jumps, teleporting, and instant state swaps.
- Reuse existing elements through translation, morphing, resizing, clipping, opacity, and layering before introducing new visual objects.
- If an element must enter or leave, make it feel physically continuous through fade, slide, scale, blur, or shape transition.

## Priority 2: Glass Liquid Visual Language

After motion continuity is satisfied, apply the project visual language.

- Build interactive regions from rounded rectangles, capsules, floating panels, and island-like containers.
- Prefer translucent surfaces with blur, tint, subtle borders, and soft highlights.
- Use glass or acrylic layering instead of flat opaque cards.
- Favor dynamic island-style surfaces, floating popups, and soft overlays over fixed Material-style app bars, cards, and FAB patterns.
- Avoid generic Material Design visuals unless an existing component intentionally requires them.
- Keep surfaces soft, layered, and fluid rather than rigid, rectangular, or heavily shadowed.

## Capsule & Rounded-Rectangle Internal Spacing Language

Use this spacing system for pill-shaped capsules, rounded-rectangle chips, and nested rounded containers across all surfaces (bar, widget, window hint capsule, etc.).

### Two-Tier Capsule Insets

| Tier | Use case | Vertical inset | Horizontal inset (per side) |
|------|----------|---------------|---------------------------|
| Compact | Narrow status pills, icon-only or icon+short-label capsules | 6px | 12px |
| Regular | Wider content capsules, workspace hints, widget containers | 8px | 16px |

- Maintain roughly a **1:2 vertical-to-horizontal inset ratio** so content clears corners without feeling loose.
- Compact tier total horizontal inset: 24px. Regular tier total horizontal inset: 32px.
- Choose the tier by capsule width and content density, not by arbitrary surface identity.

### Gap Hierarchy

| Context | Gap |
|---------|-----|
| Group-level spacing between adjacent capsules/widgets | 8px |
| Tighter inline gaps inside a capsule (e.g., icon–text) | 6px |
| Icon-to-icon or icon-to-edge gaps in dense layouts | 4–5px |

### Corner Tension Rule

- Content must stay clear of capsule corners. The inset ensures the content bounding box does not visually collide with the curved corner geometry.
- For nested rounded surfaces (e.g., a capsule inside a dockzone background), keep them **concentric**: `innerRadius = outerRadius − inset`. This preserves visual alignment of concentric curves.

### Icon–Text Balance

- When icon and text are paired inside a capsule, text size may match or sit close to the icon size if that improves visual balance.
- This is a balance heuristic, not a blanket rule: do not make dense labels comically large or cause truncation regressions.

### Source Basis

These rules are derived from Apple WWDC23 Dynamic Island fit guidance (concentric margins, avoid corner tension) and Material chip spacing norms (compact pill horizontal dominance, asymmetric vertical compression). Use them as a starting point; adjust only with visual evidence on the actual surface.

## Reusable Shape: Attached Island Surface

Use this reusable shape for compact surfaces that must feel anchored to an edge.

- Compose it as an adaptive center body plus edge-attached inner quarter-circle ear decorations.
- Keep the body and ears visually attached to the top or screen edge.
- Treat the ears as curved edge patches, not detached side bulbs.
- Preserve continuous morphing when the body grows, shrinks, or changes contents.

### Ear-Body Motion Rules

- Treat each ear as subordinate geometry of its dockzone body, not as an independent decorative object.
- Ears must inherit the body's global motion by default: translation, scale, opacity, visibility-state, and color-state changes should remain synchronized.
- If an ear needs a local effect such as detach, exit, or morph, layer that effect on top of the inherited body motion instead of replacing it.
- When a surface state change removes the need for ears, prefer a continuous ear exit transition over an instant disappearance.
- If future large-scale motion requires strict ear-body continuity, treat separate overlay-ear ownership as a transitional workaround rather than the final architecture.
- For ambitious ear/body morphing, prefer one shared geometry owner and one shared parameter model over multiple windows or independently animated shape owners.

### Attached Outline Rule

- When removing the screen-attached top highlight, derive the open stroke from the filled silhouette: preserve both complete ear arcs, side edges, and bottom edge, and omit only the final top connection.
- Do not shorten an ear arc to hide its top endpoint. Start and end the open path just outside the visible top boundary so the screen clips the lead-in, not the ear itself.
- If the stroke path traverses the filled silhouette in reverse, reverse each SVG arc sweep direction too; otherwise an ear can render on the wrong side or disappear despite valid path syntax.

### Background Hover Expand / Reset Pattern

- For dockzone-adjacent backgrounds, treat hover as a geometry expansion first and a visual highlight second.
- On hover enter, let the surface expand or lift its silhouette modestly instead of only scaling the contents.
- On hover leave, spring the surface back to its resting shape so the object reads as the same anchored background returning home.
- Keep the hover region passive and stable so moving within the surface does not retrigger the expansion.
- Use this pattern for attached backgrounds, edge anchors, and other hoverable shells that should stay layout-stable while still feeling alive.

### Global Sweep With Surface-Local Trail Pattern

Use this for one ripple, scanline, shimmer, spotlight, or wave that must read as a single event across multiple QML surfaces/windows while still appearing clipped to each shell surface.

- Drive the sweep from one singleton timeline (`progress`, `active`, `token`, duration), not from independent animations inside every surface.
- Let each surface compute the same global origin in its own local coordinates, then render the sweep/trail inside its existing clipped body or silhouette owner.
- Keep the main sweep and trailing highlight derived from the same global progress so left/right dockzones, islands, and fullscreen overlays stay phase-aligned.
- In fullscreen overlay mode, draw the main ring in the fixed full-screen window, but keep the shell-only trail visible inside each dockzone/island surface.
- Make the trail much wider and paler than the main ring; for a clear brushed highlight, start around 10-20x the main ring stroke width and tune opacity visually.
- Prefer clipped surface-local trail bands over delayed whole-surface flashes when the desired effect is “the sweep passed through this shell background”.
- Avoid per-surface timers or delayed one-shot highlights for a traveling sweep; they read as sequential flashes rather than one continuous object.

Use it for:

- Dock zones
- Dynamic islands
- Edge-attached popups
- Compact anchored status or notification surfaces

Do not use it for:

- Freely floating capsules or cards
- Unanchored surfaces that should read as independent objects

### Dockzone-Hosted Expand Surface Pattern

Use this for bar-attached content that should feel like it grows out of the dockzone rather than appearing as a separate popup.

- Host the content inside the owning dockzone or island body instead of creating an independent floating `PanelWindow` or popup window.
- Let the dockzone body expand to contain the surface while the content is clipped to the host-provided viewport during reveal.
- Keep outer padding, row height, compact spacing, content inset, separator inset, and row radius aligned with the shared menu tokens such as `MenuVisuals`.
- Make headers and content rows share the same left and right text baselines; do not add a second inner padding layer unless the row itself visually requires it.
- Keep foreground reveal synchronized with the host expansion: rows should fade or reveal only when they fit inside the expanded glass body.
- Use this pattern for tray menus, bar context menus, widget settings, widget pickers, and similar bar-attached utility surfaces.
- Avoid using this pattern for detached dialogs, fullscreen overlays, or content that should read as independent from the top bar.

## Top Status Bar Composition

Use this model for top status bar designs unless a task explicitly asks for a different shell structure.

- Treat individual status bar components as floating capsules by default.
- Group components into three top dock zones: left, center, and right.
- Give each dock zone the reusable Attached Island Surface background.
- For the visible center zone, prefer a transparent host window with a centered island surface rather than a full-width opaque bar.
- Keep dock zones as adaptive containers whose width follows their current capsule contents.
- Let components enter, leave, and move between zones through fluid motion; avoid recreating or hard-swapping the component when it changes zone.
- Prefer zone background morphing over fixed-width bars: the body should expand, contract, and soften around the active components while preserving the ear-attached outer silhouette.
- Keep visual hierarchy clear: capsules are the movable content units; dock-zone backgrounds are the stable top-edge anchors.

## QML Implementation Heuristics

When changing QML:

- First ask whether the existing item can transform into the next state.
- Prefer `Behavior`, `Transition`, `State`, and coordinated property animations over direct visibility or geometry jumps.
- Prefer moving, resizing, changing radius, clipping, opacity, and blur over destroying and recreating panel-like items.
- Avoid toggling `visible` without a matching opacity, scale, slide, or blur transition.
- Keep `PanelWindow`, popup, island, and overlay surfaces visually related through shared radius, translucency, and motion timing.
- For top bars, model left, center, and right dock zones as persistent containers whose width is animated from their contents.
- Move capsule components between dock zones by animating position and opacity rather than destroying one instance and creating another.
- For dockzone ears, centralize shared geometry state before adding large-scale motion so ear/body transforms do not drift apart across states.

### Bar Widget Width Coupling Rules

When a bar widget's content width changes (title, label, icon, or detail reveal on hover), the dockzone background, widget position, and adjacent section displacement must share a unified geometry rhythm:

- **Fixed expansion anchor**: Widget content that grows/shrinks must do so from a fixed edge — keep the content left-anchored (or right-anchored) so the expansion extends in one direction only, never from the visual center. Avoid `anchors.centerIn` for content rows whose width changes dynamically; use `anchors.left` (or `anchors.right`) with a `leftMargin`/`rightMargin` equal to the widget's visual padding.

- **Animated layout width**: The widget's `implicitWidth` must derive from the *animated* width of its expanding content, not the instantaneous target width. If the expanding inner slot uses a `Behavior` on its width (e.g., `revealWidth`), use that animated property directly in the `implicitWidth` expression so the dockzone background and the section row reflow continuously rather than jumping.

- **Coordinated content–background reveal**: The dockzone background width, the section row position, and any adjacent section push should respond to changes on the same animation timeline. Use `targetImplicitWidth`/`animImplicitWidth` with a `Behavior` for widgets whose content width changes via crossfade (e.g., `ActiveWindow` title swap), so the layout width transitions smoothly alongside the foreground transition.

- **One-directional expand priority for push**: When a section is pushed by the center surface (or an adjacent expanding widget), the push displacement should snap on increase (to avoid overlap) but spring-animate on decrease (to feel like a smooth return home). This mirrors the `DockzoneSurfaceRoot._animBodyShrinkX` pattern: `enabled` for the return spring, disabled for the expand snap.

- **Avoid double centering**: If a section row already centers its widgets within the dockzone body (via `bodyWidth - width / 2`), individual widgets must not center their internal content again. Widgets should be left-anchored (in left/center sections) or right-anchored (in right sections) so only the section-level centering handles the overall alignment.

- **Unify geometry through the section model pipeline**: Use the same `contentWidth → bodyWidth → pushedBodyWidth → visualOffset` cascade for both the glass background outline and the widget row position. Do not add independent offset/width compensations in the widget layer that bypass this chain.

## Anti-Patterns

Avoid:

- Replacing one panel with another when the first can morph.
- Toggling visibility without transition.
- Moving elements by abruptly changing layout with no animation.
- Hard-edged rectangular panels.
- Flat opaque Material-style cards.
- Standard Material FAB, app-bar, or card compositions unless intentionally required.
- A full-width opaque top bar when adaptive dock zones can express the same information.
- Independent top-bar capsules with no shared dock-zone anchoring, unless the component is intentionally transient.
