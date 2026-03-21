# Tray Context Menu Inline Design

**Date:** 2026-03-21  
**Status:** Proposed

## Goal

Make tray-icon right click open the shell's existing top-level bar context menu, then inline the clicked tray item's native context-menu entries beneath `组件设置`, separated by a divider.

The new behavior must preserve the tray item's native menu semantics while allowing the user to keep the shell menu open and right-click a different tray icon to switch the inline menu content immediately.

## Problem

The current tray interaction splits right-click behavior across two independent surfaces:

1. `modules/bar/tray/TrayIconButton.qml` directly calls `item.display(...)` for tray native menus
2. `modules/bar/BarContextMenu.qml` separately owns the shell's top-level bar and widget context menu

That creates two product limitations:

- tray right click does not integrate with the shell's existing first-level menu structure
- once a tray native menu is open, the shell cannot treat it as one consistent context surface

The requested product behavior is now explicit:

- only right-clicking a concrete tray icon should inject tray-native actions
- the injected tray section should appear below `组件设置`
- a divider should separate shell-owned items from tray-native items
- if the shell menu is already open, right-clicking another tray icon should switch context without tearing the whole menu down first

## Decision

Keep `modules/bar/BarContextMenu.qml` as the only first-level context-menu container and move tray right-click ownership upward into that menu flow.

`TrayIconButton.qml` should stop directly displaying the native tray menu on right click. Instead, it should emit a request that carries:

- the clicked tray item
- the enclosing `systemTray` widget instance key and widget-center anchor
- the click position in bar-local coordinates
- enough anchor information for `BarContextMenu.qml` to reposition itself cleanly

`BarContextMenu.qml` should then render its existing shell actions first and conditionally append one tray-native section for the currently targeted tray item.

This keeps one menu shell, one open-state owner, and one interaction model.

This design now explicitly depends on documented Quickshell tray-menu APIs:

- `SystemTrayItem.menu` exposes the tray item's menu handle
- `SystemTrayItem.hasMenu` still gates visibility
- the underlying menu tree is represented through `DBusMenuItem` and `QsMenuEntry`, which expose separator, enabled, check-state, icon, trigger, and child-menu capabilities

## Architecture

### 1. Ownership boundaries

Keep responsibilities strict:

- `modules/bar/tray/TrayIconButton.qml`
  - detects pointer input on a single tray icon
  - emits a right-click request upward
  - keeps existing left-click, middle-click, and wheel behavior intact
- `modules/bar/widgets/SystemTrayWidget.qml`
  - forwards tray-icon context requests toward bar-level composition
  - does not become a second context-menu renderer
- `modules/bar/BarContent.qml`
  - remains the bar-local composition point
  - routes tray-originated context requests into `BarContextMenu.qml`
- `modules/bar/BarContextMenu.qml`
  - stays the only first-level menu window
  - owns tray context state, divider visibility, and tray menu section rendering
- `services/SystemTrayService.qml`
  - may expose a focused adapter shape if the upstream tray menu data cannot be consumed directly by `BarContextMenu.qml`
  - must not become a second popup owner

That split follows the repo's existing service-to-module architecture: services adapt state, modules render surfaces, and one popup owns the actual window lifecycle.

### 2. Bar context menu contract

Extend `modules/bar/BarContextMenu.qml` with a tray-specific context layer.

Suggested state shape:

```qml
property var _targetTrayItem: null
property bool _hasTrayContext: false
property string _targetTrayWidgetKey: ""
property real _targetTrayWidgetCenterX: 0
readonly property bool _showTraySection: _hasTrayContext && _targetTrayItem && _targetTrayItem.hasMenu
```

Suggested public entry point direction:

```qml
function showAt(x, y, instanceKey, widgetCenterX, widgetLabel, trayItem, trayWidgetKey, trayWidgetCenterX) {}
```

Rules:

- background bar right click passes no tray item
- normal widget right click passes no tray item unless the widget is a specific tray icon target
- tray icon right click passes the clicked tray item and also passes the enclosing `systemTray` widget instance as the widget target
- menu structure remains shell-first, tray-second
- tray state must be cleared when the menu fully closes

That extra widget-target rule ensures `组件设置` stays present and stable for tray-icon right clicks, so the injected tray section is always truly inserted below it instead of depending on incidental visibility.

### 3. Tray native menu section

The tray section belongs below `组件设置` and is conditionally visible.

Required ordering:

1. `布局模式`
2. `设置`
3. `组件设置` when a widget target exists
4. divider between shell/widget actions and tray actions when tray context exists
5. native menu entries for the current tray item

The shell menu should not reinterpret tray actions as custom shell actions. It should host them.

Product rule:

- if the current tray item has no native menu, the tray section does not appear
- if the tray item disappears while the menu is open, the tray section collapses away safely without breaking the shell-owned section above it

### 4. Native-menu adaptation

The implementation should prefer the smallest adapter needed to render upstream native menu content inside the shell menu.

Use this order of preference:

1. consume `trayItem.menu` as the authoritative root handle and render from its `QsMenuEntry` / `DBusMenuItem` capabilities
2. if direct module-level consumption becomes noisy, add a focused adapter in `SystemTrayService.qml` that normalizes one tray item's current menu tree into a UI-friendly structure without changing ownership

Adapter requirements if needed:

- preserve item order
- preserve separators
- preserve enabled and checked state where available
- preserve submenu hierarchy where available
- avoid flattening away meaningful grouping
- treat unavailable or unsupported entry shapes as skippable, not fatal

Suggested minimum render contract:

- use `isSeparator` to render dividers
- use `text`, `icon`, `enabled`, and `checkState` for row presentation
- use `triggered()` for leaf activation
- use `hasChildren` plus child-opening support for submenus
- if a specific submenu branch is easier to host through Quickshell's native menu opener than through custom inline expansion, that is acceptable as long as the first-level menu remains the shell-owned surface

This is similar to putting one restaurant's menu onto a shared table stand: the shell supplies the stand, but the dish list still belongs to the restaurant.

## Interaction Model

### 1. Right-click behavior

Right click on a concrete tray icon should:

- open the shell context menu if it is closed
- update the active tray context if it is already open
- move the menu anchor to the new click position
- replace only the tray-native section content for the newly targeted icon

Event chain requirement:

1. `TrayIconButton.qml` emits a tray-context request
2. `SystemTrayWidget.qml` forwards that request together with the enclosing `systemTray` instance metadata
3. `BarContent.qml` calls `BarContextMenu.showAt(...)` on the already-instantiated popup
4. `BarContextMenu.qml` updates context fields in place when already visible instead of toggling visibility off and on

It should **not**:

- spawn a second native popup in parallel
- close the whole shell menu first just to reopen it for another tray icon
- change left-click or middle-click activation semantics

### 2. While the menu is already open

If the first-level menu is visible and the user right-clicks a different tray icon:

- keep the same `PopupWindow` alive
- keep the menu in its open state
- update tray context fields in place
- reset any tray-section-local hover or submenu state that would otherwise leak across icons
- rerun any stagger or visibility bookkeeping only as needed for the changed section

The result should feel like switching the active source inside one stable menu, not like destroying and recreating the whole surface.

This is viable with the current menu placement because `BarContextMenu.qml` already anchors itself below the bar rather than on top of the tray icons, so the bar row remains directly right-clickable while the popup is open.

### 3. Other pointer behavior

Keep existing semantics unchanged outside right click:

- left click still prefers `activate()`
- `onlyMenu` items may still route left click to menu behavior if that is already the product contract
- middle click still uses `secondaryActivate()` when enabled
- wheel still routes through `scroll(...)`

This limits the scope to the requested context-menu integration instead of redefining tray activation behavior.

## Closing Rules

Closing behavior should stay uniform regardless of whether the clicked action came from the shell section or the tray-native section.

Required rules:

- clicking a shell action uses the existing delayed dismiss flow
- clicking a tray-native action should use the same dismiss policy unless the upstream native action explicitly requires the menu to stay open for submenu interaction
- clicking outside the menu closes the entire first-level menu and clears tray context
- pressing `Esc` closes the menu and clears tray context
- external `BarLayoutService.contextMenuOpen = false` closes the menu and clears tray context

When the menu closes, tray context must return to a neutral state so a later bar-background right click does not accidentally show stale tray actions.

## Error Handling and Edge Cases

Treat tray menu integration as recoverable UI state, not a critical-path assumption.

Required fallbacks:

- missing tray item => hide tray section
- tray item with `hasMenu: false` => hide tray section
- unsupported menu node shape => skip that node and continue rendering siblings
- tray item removed while targeted => clear tray section and keep shell menu usable
- rapid right-click switching between tray icons => latest click wins

No failure in tray-native rendering should block `布局模式`, `设置`, or `组件设置` from remaining usable.

## File Impact

### Modified files

- `modules/bar/tray/TrayIconButton.qml`
  - replace direct tray-menu popup ownership on right click with an upward request signal
- `modules/bar/widgets/SystemTrayWidget.qml`
  - forward tray context-menu requests toward the bar composition layer
- `modules/bar/BarContent.qml`
  - route tray-icon right-click requests into `BarContextMenu.qml`
- `modules/bar/BarContextMenu.qml`
  - add tray target state, tray divider, tray menu section, and in-place context switching behavior

### Possibly modified file

- `services/SystemTrayService.qml`
  - only if a focused adapter is needed between upstream tray menu data and the shell menu renderer

## Verification

Implementation should prove the following behaviors:

- right-clicking a tray icon opens the shell context menu with tray-native entries below `组件设置`
- right-clicking bar background does not show tray-native entries
- right-clicking tray empty space does not show tray-native entries
- switching right click from one tray icon to another while the menu is open updates content in place
- tray items without menus do not create empty tray sections
- tray-item disappearance while open does not break the shell menu

Targeted verification is required in addition to shell load checks.

Recommended harness directions:

- add a QML harness under `tests/` that mounts `BarContextMenu.qml` with fake tray targets and exercises tray-context switching
- explicitly verify `组件设置` remains visible for tray-icon right click because the enclosing `systemTray` widget target is preserved
- explicitly verify in-place switching does not flip the popup through a closed state
- explicitly verify tray target removal clears only the tray section and not the shell-owned items above it

Repo-level validation commands:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

If implementation introduces a targeted QML harness, keep it under `tests/` and make it verify interaction state transitions rather than only visual appearance.

## Recommended Implementation Direction

Implement this as a context-ownership change, not as a duplicated popup.

Start from the event path:

1. tray icon emits right-click request upward
2. bar composition passes the targeted tray item into `BarContextMenu.qml`
3. `BarContextMenu.qml` becomes the only first-level owner of shell plus tray menu content
4. add a minimal adapter only if the upstream tray menu model cannot be rendered directly

That sequencing keeps the architecture honest: one popup window, one active context, one menu tree.
