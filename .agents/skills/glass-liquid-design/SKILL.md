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

### Background Hover Expand / Reset Pattern

- For dockzone-adjacent backgrounds, treat hover as a geometry expansion first and a visual highlight second.
- On hover enter, let the surface expand or lift its silhouette modestly instead of only scaling the contents.
- On hover leave, spring the surface back to its resting shape so the object reads as the same anchored background returning home.
- Keep the hover region passive and stable so moving within the surface does not retrigger the expansion.
- Use this pattern for attached backgrounds, edge anchors, and other hoverable shells that should stay layout-stable while still feeling alive.

Use it for:

- Dock zones
- Dynamic islands
- Edge-attached popups
- Compact anchored status or notification surfaces

Do not use it for:

- Freely floating capsules or cards
- Unanchored surfaces that should read as independent objects

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
