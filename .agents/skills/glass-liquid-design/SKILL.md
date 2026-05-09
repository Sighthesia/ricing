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

## QML Implementation Heuristics

When changing QML:

- First ask whether the existing item can transform into the next state.
- Prefer `Behavior`, `Transition`, `State`, and coordinated property animations over direct visibility or geometry jumps.
- Prefer moving, resizing, changing radius, clipping, opacity, and blur over destroying and recreating panel-like items.
- Avoid toggling `visible` without a matching opacity, scale, slide, or blur transition.
- Keep `PanelWindow`, popup, island, and overlay surfaces visually related through shared radius, translucency, and motion timing.

## Anti-Patterns

Avoid:

- Replacing one panel with another when the first can morph.
- Toggling visibility without transition.
- Moving elements by abruptly changing layout with no animation.
- Hard-edged rectangular panels.
- Flat opaque Material-style cards.
- Standard Material FAB, app-bar, or card compositions unless intentionally required.
