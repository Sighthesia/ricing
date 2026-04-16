# Component Guidelines

> How components are built in this project.

---

## Overview

Components are small QML files that own one visible responsibility. Compose
larger behavior from reusable base components instead of building ad-hoc local
copies.

---

## Component Structure

Follow the local QML ordering used in the repo: imports, purpose comment, root
`id`, public properties, private state, signals, child items, helper functions,
and lifecycle handlers.

Prefer `default property alias` when a component acts as a slot container, such
as `AnimatedPanelBase.qml` and `BarWidgetWrapper.qml`.

---

## Props Conventions

Use `required property` for parent-provided inputs, typed properties for known
values, and `readonly property` for derived values. Reserve `property var` for
dynamic maps, JSON payloads, or model data.

Private implementation details must be prefixed with `_`.

---

## Styling Patterns

Use `Theme.*` and `Colors.*` for all shared sizing, animation, and palette
choices. Reuse shared surface components such as `AnimatedPanelBase.qml`,
`BarWidgetWrapper.qml`, `HoverRevealHighlight.qml`, and `ClickRipple.qml`.

Avoid feature-level hardcoded colors and timing literals unless the theme does
not yet expose the value.

Shared floating shells should use `modules/bar/FloatingShellSurface.qml` and
`config/ThemeCards.qml` shell tokens instead of recreating border/radius/fill
rectangles locally. Prefer the `shell*` token family when a panel, popup, or
expanded surface should read like the SuperIsland family.

Attached SuperIsland shells should derive edge-aware corner behavior from
`Theme.screenCornerRadius` and keep bridge geometry in shared helpers such as
`modules/bar/AttachedExpansionGeometry.js` so the pill-to-panel shape stays
consistent across surfaces.

---

## Accessibility

Keep interactive surfaces keyboard-safe and pointer-friendly:

- Provide `cursorShape` and hover feedback for clickable surfaces.
- Close transient panels with `Escape` when possible.
- Use `TapHandler` / `MouseArea` / `HoverHandler` deliberately and keep hover
  regions aligned with the visual affordance.

Examples: `modules/bar/widgets/SystemTrayWidget.qml`, `modules/bar/widgets/WorkspaceWidget.qml`, `modules/bar/BarContent.qml`.

(To be filled by the team)

---

## Common Mistakes

<!-- Component-related mistakes your team has made -->

(To be filled by the team)
