# DymicShell — AI Agent Context

A Wayland shell built with Quickshell, following a strict three-layer architecture:
`services/` (singleton state) → `config/` (derived tokens) → `modules/` (UI rendering).

## Repository Structure

```
shell.qml                  # Entry point — declares top-level window instances only
config/
  Colors.qml               # Semantic color tokens (Singleton)
  Theme.qml                # Structural tokens: sizes, fonts, animation durations (Singleton)
  settings-default.json    # All default config values (single source of truth)
services/
  SettingsService.qml      # JSON persistence + hot-reload; exposes SettingsService.data.*
  BarLayoutService.qml     # Active panel state, widget layout
  NiriService.qml          # Niri compositor workspace integration
  WallpaperService.qml     # Wallpaper switching + Matugen color extraction
modules/
  bar/                     # Bar window and all overlay windows
  background/              # Background and wallpaper picker
```

## Token System (mandatory — never use magic numbers)

### Colors: `Colors.*`
All color properties are `readonly property color`. **Never hardcode hex values.**

Colors derive from `SettingsService.data.appearance.*`; Matugen overrides are injected via `_mc(key, fallback)`.

Common tokens: `Colors.background`, `Colors.text`, `Colors.border`, `Colors.highlight`

### Animation: `Theme.anim.*`
All animation durations and easing curves **must** reference this namespace.

| Token                          | Purpose                    | Base duration | Easing              |
| ------------------------------ | -------------------------- | ------------- | ------------------- |
| `Theme.anim.enterDuration`     | Bounce-in                  | 500 ms        | `Easing.OutElastic` |
| `Theme.anim.exitDuration`      | Snap-out                   | 220 ms        | `Easing.InExpo`     |
| `Theme.anim.moveDuration`      | Position/width transitions | 320 ms        | `Easing.InOutCubic` |
| `Theme.anim.highlightDuration` | Hover highlight pulse      | 180 ms        | `Easing.OutQuad`    |

Companion easing properties (same prefix, `Type` suffix): `Theme.anim.enterType`, `Theme.anim.exitType`, etc.

All durations are computed as `Math.round(baseMs / SettingsService.data.animation.speedFactor)` so the user can scale all animations globally.

> **Known exceptions**: `AnimatedPanelBase.qml` and `ClickRipple.qml` currently hardcode durations.
> Mark any new hardcoded duration with `// FIXME: use Theme.anim.*`.

### Sizes and Fonts: `Theme.*`
Use `Theme.barHeight`, `Theme.fontFamily`, `Theme.fontSize`, etc. No fixed pixel values.

## Settings Data Access

Read settings exclusively via `SettingsService.data.<section>.<key>`:

```qml
SettingsService.data.appearance.backgroundColor   // color
SettingsService.data.bar.height                   // size
SettingsService.data.animation.speedFactor        // animation speed
SettingsService.data.barBehavior.autoHide         // behavior flag
```

Write via `SettingsService.save()`. Internally debounced at 500 ms.

## Reusable Base Components (prefer over reimplementing)

| Component              | Path                                   | Usage                                                             |
| ---------------------- | -------------------------------------- | ----------------------------------------------------------------- |
| `AnimatedPanelBase`    | `modules/bar/AnimatedPanelBase.qml`    | Base for all dropdown panels; use `active:` instead of `visible:` |
| `StaggerItem`          | `modules/bar/StaggerItem.qml`          | Stagger enter/exit wrapper for list items                         |
| `HoverRevealHighlight` | `modules/bar/HoverRevealHighlight.qml` | Shell-wide wipe-reveal hover highlight                            |
| `ClickRipple`          | `modules/bar/ClickRipple.qml`          | Click ripple overlay; call `ripple.triggerRipple(m.x, m.y)`       |
| `BarWidgetWrapper`     | `modules/bar/BarWidgetWrapper.qml`     | Bar widget container with enter animation and drag support        |

### Interactive Item Pattern (use all three together)

```qml
HoverRevealHighlight { anchors.fill: parent; hovered: area.containsMouse }
ClickRipple { id: ripple; anchors.fill: parent }
MouseArea {
    id: area
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: (mouse) => { ripple.triggerRipple(mouse.x, mouse.y); /* business logic */ }
}
```

### Implicit Property Animation Pattern

```qml
Behavior on implicitWidth {
    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
}
```

## QML File Structure

Follow this ordering within every QML file:

```
1. import statements     (Quickshell → Qt → qs.config → qs.services → qs.modules → relative)
2. Top-level comment     (component purpose + usage note)
3. Root id
4. required property     (must be supplied by parent)
5. property              (public mutable state)
6. readonly property     (derived/computed)
7. property _xxx         (private state — underscore prefix)
8. signal
9. Child component declarations
10. Functions            (public API first, private helpers after)
11. Component.onCompleted
12. Connections
```

## Key Conventions

- **Private members**: prefix with `_` (e.g., `_state`, `_mc`). Public API has no prefix.
- **Animated windows**: use a `_state: string` state machine (`"closed"`, `"opening"`, `"open"`, `"closing"`) instead of toggling `visible` directly — prevents premature Wayland surface destruction.
- **`AnimatedPanelBase` children**: routed via `default property alias`; place child items directly inside the component tag.
- **`Behavior on` + token**: the standard pattern for implicit animation — always pair with `Theme.anim.*` tokens, never inline literal durations or easing values.
