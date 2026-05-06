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

### Convention: Extract feature-local visual tokens before scene splitting

When a visual family grows beyond a single component, first extract the most
stable feature-local style values into a dedicated token owner under `config/`
before splitting scenes, shells, or state-machine ownership.

**Good**:
- Keep global tokens in `Theme.qml` / `Colors.qml`.
- Move feature-only geometry such as preview widths, deck chrome spacing, or
  hint-specific stage padding into a dedicated file such as
  `config/ThemeSuperIsland.qml`.
- Let large host files keep their current behavior while they switch from local
  literals to the shared feature-local tokens.

**Avoid**:
- Starting a large visual refactor by moving scenes and behavior while style
  literals still live inline across several files.
- Promoting feature-specific geometry into global theme files when the values do
  not belong to the wider shell system.

**Why**: a token-extraction-first slice improves discoverability, reduces
duplicate literals, and creates a lower-risk boundary for later architecture
cleanup.

**Example**:
```qml
// Feature-local visual tokens keep SuperIsland-only geometry out of host files.
Singleton {
    readonly property int windowHintStagePadH: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int expandedDeckMargin: 12
}
```

### Convention: Extract helper objects before splitting behavior

When a host component grows large, first extract pure derived clusters into a
small helper object before moving interaction logic.

**Good**:
- Move stable geometry, screen fallback, or mode-flag clusters into a helper
  `QtObject` / `Item`.
- Keep the host wiring those values through aliases so existing call sites do
  not change.

**Avoid**:
- Moving motion/state-machine logic and geometry in the same slice.
- Replacing host properties with ad-hoc duplicated copies in multiple children.

**Why**: it reduces host complexity without changing runtime behavior, and it
creates a safe boundary for later refactors.

**Example**:
```qml
// Overlay geometry helper owns screen info and shell shape properties.
QtObject {
    id: overlayGeometry
    required property bool barExpandedHintActive
    required property real pillHeight
}
```

### Convention: Keep host export contracts on the host during slimming

When slimming a large composition root, it is safe to move pure derived
geometry, width-chain, or reveal-chain calculations into feature-local helpers,
but the root should keep owning any exported layout or measurement contracts
consumed by wrapper-level infrastructure.

**Good**:
- Extract derived clusters such as track geometry, reveal progress, or width
  decisions into focused helper `QtObject` / `Item` files.
- Re-expose host-owned contracts like layout measurement or reservation widths
  through host aliases/bindings after the calculation moves.
- Keep visual leaf chrome, decorative canvases, and other non-owning surfaces in
  separate child components when they do not own behavior.

**Avoid**:
- Moving wrapper-consumed exports directly into a helper and forcing outer
  layout code to chase a new path.
- Mixing helper extraction with loader ownership, state-machine rewrites, or
  service ownership changes in the same slice.

**Why**: this keeps host slimming low risk. The root becomes smaller, but the
layout contract stays stable for `BarWidgetWrapper` and other downstream
consumers.

**Example**:
```qml
// Host still owns the exported contract even when a helper computes the value.
readonly property real layoutMeasurementWidth: _hostGeometry.layoutMeasurementWidth

// Helper owns the pure width-chain math only.
FeatureWidthGeometry {
    id: _hostGeometry
    host: root
}
```

### Convention: Separate scene routing from surface ownership

When one visual family supports multiple presentations of the same feature,
split the composition so one owner chooses *which* presentation is active and a
different owner draws any shared backdrop or decorative surface chrome.

**Good**:
- Let a scene component route between default, combined, detached, or similar
  presentation branches.
- Let a surface component own shared backdrops, pulse layers, and decorative
  corner pieces reused by one presentation family.
- Keep card/root components focused on shared state, snapshot data, and derived
  geometry instead of also owning every visible branch.

**Avoid**:
- Mixing scene selection, shared backdrop drawing, and state snapshot logic in
  one large presentation root.
- Forcing a host widget to know the internal decorative structure of each
  presentation branch.

**Why**: this makes visible ownership easier to locate, keeps composition roots
smaller, and prepares the feature for a later motion-ownership refactor without
changing current behavior first.

**Example**:
```qml
// Scene owner chooses the active presentation branch.
Item {
    Loader {
        sourceComponent: isCombined ? combinedScene : defaultScene
    }
}

// Surface owner draws the shared backdrop for one presentation family.
Item {
    Rectangle { /* title lane surface */ }
    Rectangle { /* workspace lane surface */ }
}
```

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
