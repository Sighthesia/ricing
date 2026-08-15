# Frontend Quality Guidelines

## Scenario: Testable QML Tokens And Per-Screen Notification Hosts

### 1. Scope / Trigger

- Apply when a QML singleton exposes visual tokens used by QtTest components.
- Apply when a transient surface is positioned per screen from a service setting.
- The goal is to preserve isolated component tests and prevent fullscreen pointer interception.

### 2. Signatures

- Visual token singleton: static/read-only QML values with no service imports.
- Notification placement service:
  - `notificationPosition: string`
  - `notificationTop: bool`
  - `notificationBottom: bool`
  - `notificationLeft: bool`
  - `notificationRight: bool`
  - `dismissPopup(notifId)`
- Notification host: `Variants { model: Quickshell.screens }` containing one `PanelWindow` per screen.

### 3. Contracts

- `notificationPosition` accepts `top-left`, `top-right`, `bottom-left`, or `bottom-right`; invalid values normalize to `top-right`.
- A notification popup model entry contains `notifId`, `appName`, `summary`, `body`, `icon`, and `timestamp`.
- `dismissPopup(notifId)` removes only the matching transient popup and does not remove notification history.
- A per-screen host uses `implicitWidth`/`implicitHeight`, `ExclusionMode.Ignore`, and a `Region` mask limited to the visible stack.
- Dynamic settings are consumed by the visible component or service owner. Shared token singletons stay independent of full service graphs.

### 4. Validation & Error Matrix

- Invalid notification position -> normalize to `top-right`.
- Missing optional popup strings -> render empty text or the stable fallback app label.
- Missing/invalid visual numeric setting -> clamp or use the existing default before assigning to geometry/color properties.
- Fullscreen notification mask -> reject; it can starve pointer events outside cards.
- Visual token singleton imports `SettingsService` -> reject; it makes otherwise pure QtTest components load Quickshell plugins.

### 5. Good/Base/Bad Cases

- Good: a bottom-left setting anchors a narrow per-screen window at bottom-left and stacks cards upward.
- Base: an empty popup model leaves a one-pixel transparent host with no interactive mask.
- Bad: a fullscreen transparent `PanelWindow` owns the notification stack mask and intercepts unrelated desktop input.
- Bad: `LazerTheme.qml` imports services so `tst_lazer_settings_controls.qml` cannot run with `qmltestrunner`.

### 6. Tests Required

- Pure QtTest verifies notification top/bottom direction, popup geometry, and dismiss signal.
- Pure QtTest verifies settings controls and theme tokens load without Quickshell plugins.
- Overlay lifecycle tests run sequentially; repeat them to expose focus/event timing races.
- `qs -p .` must reach `Configuration Loaded` with no QML WARN/ERROR. A D-Bus ownership warning is environmental only when another running shell instance is confirmed as the owner.
- Run `git diff --check` after QML changes.

### 7. Wrong vs Correct

#### Wrong

```qml
// Pulls the complete service graph into every component importing this token singleton.
readonly property color panel: SettingsService.appearance.colorScheme === "light"
        ? "white" : "black"
```

```qml
PanelWindow {
    implicitWidth: screen.width
    implicitHeight: screen.height
    mask: Region { item: fullscreenOverlay }
}
```

#### Correct

```qml
// Keep shared visual tokens pure; consume live settings at the visible surface.
readonly property color panel: "#F21D1C22"
```

```qml
PanelWindow {
    implicitWidth: notificationStack.implicitWidth
    implicitHeight: Math.max(1, notificationStack.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: notificationStack.implicitHeight > 0 ? notificationStack : null }
}
```
