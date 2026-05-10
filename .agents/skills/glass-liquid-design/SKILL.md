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

## Top Status Bar Composition

Use this model for top status bar designs unless a task explicitly asks for a different shell structure.

- Treat individual status bar components as floating capsules by default.
- Group components into three top dock zones: left, center, and right.
- Give each dock zone a notch-like glass background: attached to the top screen edge, square at the top corners, rounded along the bottom edge.
- Keep dock zones as adaptive containers whose width follows their current capsule contents.
- Let components enter, leave, and move between zones through fluid motion; avoid recreating or hard-swapping the component when it changes zone.
- Prefer zone background morphing over fixed-width bars: the background should expand, contract, and soften around the active components.
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
