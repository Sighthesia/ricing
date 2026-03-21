# Tray Context Menu Inline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make right-clicking a concrete tray icon open the shell's existing first-level bar context menu and inline that tray item's native menu entries below `组件设置`, while allowing the open menu to switch to another tray icon in place.

**Architecture:** Keep `modules/bar/BarContextMenu.qml` as the only first-level popup owner, move tray right-click ownership upward through the tray widget stack, and render tray-native menu entries from `SystemTrayItem.menu` inside one dedicated tray section below the existing shell-owned rows. Extract the repeated menu-row surface into a focused child component so `BarContextMenu.qml` can host both shell rows and tray rows without turning into one monolithic file, and prove the new state transitions with a dedicated QML harness before wiring live pointer forwarding.

**Tech Stack:** Quickshell, QML, `Quickshell.Services.SystemTray`, `SystemTrayItem.menu`, `DBusMenuItem` / `QsMenuEntry`, `PopupWindow`, QML harness verification, `timeout 5 qs --path .`, `timeout 5 qs -p .`

---

## File Structure

### New files

- `tests/qml/bar/TrayContextMenuHarness.qml`
  - Single QML harness entry that exercises shell-only rows, tray-section injection, in-place tray-context switching, and targeted tray removal.
- `tests/run-tray-context-menu-harness.sh`
  - Thin wrapper for running the tray context-menu harness from repo root with a named mode.
- `modules/bar/contextmenu/BarContextMenuEntry.qml`
  - Reusable row surface for shell-owned and tray-owned first-level menu entries with highlight, ripple, icon, label, enabled-state, and click handling.
- `modules/bar/contextmenu/TrayContextMenuSection.qml`
  - Focused tray-native section renderer that accepts one tray item, resolves the menu root, renders top-level entries inline, and delegates submenu display to the upstream menu entry when needed.

### Modified files

- `modules/bar/BarContextMenu.qml`
  - Gains tray context state, tray-section insertion below `组件设置`, stable in-place context switching, and extraction of repeated row UI into `BarContextMenuEntry.qml`.
- `modules/bar/tray/TrayIconButton.qml`
  - Replaces direct tray popup ownership on right click with an upward request signal while keeping left-click, middle-click, and wheel behavior unchanged.
- `modules/bar/tray/TrayPinnedRow.qml`
  - Forwards tray-icon right-click requests from pinned delegates.
- `modules/bar/tray/TrayFlashRow.qml`
  - Forwards tray-icon right-click requests from flash-strip delegates.
- `modules/bar/widgets/SystemTrayWidget.qml`
  - Aggregates tray-icon right-click requests, exposes the enclosing `systemTray` widget identity, and forwards bar-local context-menu requests upward.
- `modules/bar/BarContent.qml`
  - Adds one public tray-context entry point that routes the targeted tray item plus widget metadata into `BarContextMenu.qml`.
- `modules/bar/BarSection.qml`
  - Injects only `hostInstanceKey` into widgets that opt into receiving their wrapper identity, so `SystemTrayWidget.qml` can preserve `组件设置` placement on tray-icon right click without widening the loader contract more than necessary.

### Verification targets

- `tests/qml/bar/TrayContextMenuHarness.qml`
- `tests/run-tray-context-menu-harness.sh`
- `modules/bar/contextmenu/BarContextMenuEntry.qml`
- `modules/bar/contextmenu/TrayContextMenuSection.qml`
- `modules/bar/BarContextMenu.qml`
- `modules/bar/tray/TrayIconButton.qml`
- `modules/bar/tray/TrayPinnedRow.qml`
- `modules/bar/tray/TrayFlashRow.qml`
- `modules/bar/widgets/SystemTrayWidget.qml`
- `modules/bar/BarContent.qml`
- `modules/bar/BarSection.qml`

---

### Task 1: Establish the tray context-menu harness and row contract

**Files:**
- Create: `tests/qml/bar/TrayContextMenuHarness.qml`
- Create: `tests/run-tray-context-menu-harness.sh`
- Create: `modules/bar/contextmenu/BarContextMenuEntry.qml`
- Modify: `modules/bar/BarContextMenu.qml`

- [ ] **Step 1: Write the failing tray harness entry and runner**

Create `tests/run-tray-context-menu-harness.sh`:

```bash
#!/usr/bin/env sh
set -eu

MODE="${1:-all}"
timeout 5 qs -p tests/qml/bar/TrayContextMenuHarness.qml -- "$MODE"
```

Create `tests/qml/bar/TrayContextMenuHarness.qml` with explicit imports, `Quickshell.args` mode switching, and fake tray-menu objects that match the minimum `QsMenuEntry` shape the UI cares about:

```qml
import QtQuick
import Quickshell
import "../../../modules/bar"

Item {
    id: root
    width: 480
    height: 360

    readonly property string mode: Quickshell.args.length > 0 ? Quickshell.args[0] : "all"

    function expect(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    QtObject {
        id: fakeLeaf
        property string text: "Open Dashboard"
        property bool enabled: true
        property bool isSeparator: false
        property bool hasChildren: false
        property string icon: ""
        property var checkState: Qt.Unchecked
        signal triggered()
    }

    QtObject {
        id: fakeSubLeaf
        property string text: "Nested Action"
        property bool enabled: true
        property bool isSeparator: false
        property bool hasChildren: false
        property string icon: ""
        property var checkState: Qt.Unchecked
        signal triggered()
    }

    QtObject {
        id: fakeSubmenu
        property string text: "Advanced"
        property bool enabled: true
        property bool isSeparator: false
        property bool hasChildren: true
        property string icon: ""
        property var checkState: Qt.Unchecked
        property bool showChildren: false
        property var children: [fakeSubLeaf]
        signal triggered()
        function display(_parentWindow, _relativeX, _relativeY) {
            showChildren = true
        }
    }

    QtObject {
        id: fakeSeparator
        property bool isSeparator: true
    }

    QtObject {
        id: fakeMenuRoot
        property bool showChildren: true
        property var children: [fakeLeaf, fakeSeparator, fakeSubmenu]
        function updateLayout() {}
    }

    QtObject {
        id: fakeTrayItem
        property bool hasMenu: true
        property var menu: fakeMenuRoot
        property string id: "tray-demo"
    }
}
```

Add initial modes:

- `shell-only` expects the two built-in shell rows to still render
- `tray-inline` expects a tray-context-capable `BarContextMenu` to expose tray rows below `组件设置`, keep the tray separator visible, and render the submenu row as a non-leaf entry

Make the initial assertions explicit:

- `shell-only` checks that `布局模式` and `设置` are still present
- `tray-inline` checks that the tray block beneath `组件设置` contains exactly three top-level rows in order: `Open Dashboard`, one separator, and `Advanced`
- `tray-inline` also checks that activating `Advanced` flips the fake submenu object's `showChildren` flag instead of emitting the leaf `triggered()` path

- [ ] **Step 2: Run the tray-inline mode to verify it fails for the expected reason**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh tray-inline
```

Expected: FAIL because `BarContextMenu.qml` does not yet expose tray context state or an inline tray section.

- [ ] **Step 3: Extract a reusable first-level row component**

Create `modules/bar/contextmenu/BarContextMenuEntry.qml` as the shared surface for shell-owned and tray-owned rows. Keep it small and geometry-focused:

```qml
import QtQuick
import qs.config
import ".." as BarComponents

Item {
    id: root

    required property string label
    property string iconText: ""
    property bool enabled: true
    property bool hovered: false
    signal activated(real clickX, real clickY)
}
```

The component should own:

- `HoverRevealHighlight`
- `ClickRipple`
- icon + label layout
- disabled-state opacity
- one `MouseArea` that emits `activated(...)`

- [ ] **Step 4: Refactor the existing shell rows in `BarContextMenu.qml` to use `BarContextMenuEntry.qml`**

Replace the duplicated `布局模式` and `设置` row markup with `BarContextMenuEntry.qml`, but do not add tray rows yet. Also add the tray-context state placeholders that the harness will need next:

```qml
property var _targetTrayItem: null
property bool _hasTrayContext: false
property string _targetTrayWidgetKey: ""
property real _targetTrayWidgetCenterX: 0
```

- [ ] **Step 5: Re-run the shell-only harness mode**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh shell-only
```

Expected: PASS.

- [ ] **Step 6: Re-run the tray-inline mode and confirm it still fails on the missing tray section**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh tray-inline
```

Expected: FAIL because the tray section renderer does not exist yet.

---

### Task 2: Render tray-native menu entries inside `BarContextMenu.qml`

**Files:**
- Create: `modules/bar/contextmenu/TrayContextMenuSection.qml`
- Modify: `modules/bar/BarContextMenu.qml`
- Modify: `tests/qml/bar/TrayContextMenuHarness.qml`
- Verify: `docs/superpowers/specs/2026-03-21-tray-context-menu-inline-design.md`

- [ ] **Step 1: Extend the harness with switching and removal modes**

Add two new harness modes before writing implementation:

- `tray-switch` — opens the menu for `fakeTrayItem`, then swaps to `fakeTrayItemB`, and expects the tray rows to change without the popup toggling closed
- `tray-removed` — opens with tray context, then clears the tray target and expects shell rows to remain while the tray section disappears

Add a second fake tray item with a distinct first entry label:

```qml
QtObject {
    id: fakeLeafB
    property string text: "Mute Alerts"
    property bool enabled: true
    property bool isSeparator: false
    property bool hasChildren: false
    property string icon: ""
    property var checkState: Qt.Unchecked
    signal triggered()
}
```

In the new assertions, be explicit:

- `tray-switch` must prove `Open Dashboard` disappears and `Mute Alerts` appears while both `visible` and `_active` stay truthy for the whole switch path
- `tray-removed` must prove `布局模式`, `设置`, and `组件设置` remain while all tray-owned rows disappear

- [ ] **Step 2: Run the switch and removal modes to verify they fail correctly**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh tray-switch
sh tests/run-tray-context-menu-harness.sh tray-removed
```

Expected: both FAIL because `BarContextMenu.qml` still lacks tray-section rendering and in-place tray-context updates.

- [ ] **Step 3: Create `TrayContextMenuSection.qml`**

Create a focused section component that accepts one tray item and one popup parent, then renders only the tray item's top-level menu entries inline.

Suggested contract:

```qml
import QtQuick
import qs.config
import "." as ContextMenuParts

Item {
    id: root

    required property var trayItem
    required property QtObject menuParent
    readonly property var _menuRoot: trayItem && trayItem.hasMenu ? trayItem.menu : null
    readonly property var _entries: _menuRoot && _menuRoot.children ? _menuRoot.children : []
}
```

Rules to implement:

- call `root._menuRoot.updateLayout()` when available before first render
- render separators when `entry.isSeparator` is true
- render regular rows through `BarContextMenuEntry.qml`
- if `entry.hasChildren` is true, open the submenu from the clicked row via `entry.display(root.menuParent, clickX, clickY)`
- otherwise trigger leaf entries through `entry.triggered()`
- if an entry shape is unsupported, skip it instead of failing the whole section

- [ ] **Step 4: Mount the tray section below `组件设置` in `BarContextMenu.qml`**

Implement all tray-specific popup state and wire it into `showAt(...)`.

Required structure:

```qml
function showAt(x, y, instanceKey, widgetCenterX, widgetLabel, trayItem, trayWidgetKey, trayWidgetCenterX) {
    _clickX = x
    _targetWidgetKey = trayWidgetKey || instanceKey || ""
    _targetWidgetCenterX = trayWidgetCenterX || widgetCenterX || 0
    _targetTrayItem = trayItem || null
    _hasTrayContext = _targetTrayItem !== null
}
```

Required menu ordering:

1. `布局模式`
2. `设置`
3. `组件设置` when a widget target exists
4. one divider only when tray context exists and `trayItem.hasMenu` is true
5. `TrayContextMenuSection.qml`

When the popup is already visible, `showAt(...)` must update these fields in place and keep `_active` true instead of closing and reopening the popup.

- [ ] **Step 5: Re-run the tray harness modes**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh shell-only
sh tests/run-tray-context-menu-harness.sh tray-inline
sh tests/run-tray-context-menu-harness.sh tray-switch
sh tests/run-tray-context-menu-harness.sh tray-removed
```

Expected: PASS.

- [ ] **Step 6: Run the shell-level validation commands**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 7: Commit the inline tray section**

```bash
git add modules/bar/contextmenu/BarContextMenuEntry.qml modules/bar/contextmenu/TrayContextMenuSection.qml modules/bar/BarContextMenu.qml tests/qml/bar/TrayContextMenuHarness.qml tests/run-tray-context-menu-harness.sh
git commit -m "feat: inline tray menu entries in bar context menu"
```

---

### Task 3: Plumb live tray-icon right click into the shared popup owner

**Files:**
- Modify: `modules/bar/tray/TrayIconButton.qml`
- Modify: `modules/bar/tray/TrayPinnedRow.qml`
- Modify: `modules/bar/tray/TrayFlashRow.qml`
- Modify: `modules/bar/widgets/SystemTrayWidget.qml`
- Modify: `modules/bar/BarContent.qml`
- Modify: `modules/bar/BarSection.qml`
- Verify: `modules/bar/BarWidgetWrapper.qml`
- Verify: `modules/bar/BarContextMenu.qml`

- [ ] **Step 1: Extend the harness with a host-widget preservation mode**

Add a `tray-widget-target` mode that directly calls the tray-capable `showAt(...)` path with:

- a tray item
- `trayWidgetKey: "systemTray_0"`
- `trayWidgetCenterX: 180`
- `clickY: 0`

Then assert:

- the popup still exposes `组件设置`
- the tray section appears below it
- clearing tray context does not clear the preserved widget target unless the popup fully closes

- [ ] **Step 2: Run the new mode to verify it fails**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh tray-widget-target
```

Expected: FAIL because live widget identity is not yet modeled separately from ordinary widget right-click state.

- [ ] **Step 3: Add opt-in host identity injection in `BarSection.qml`**

When a widget instance loads, populate only the optional `hostInstanceKey` property if the widget declares it:

```qml
onLoaded: {
    if (item && item.hasOwnProperty("liveInstance"))
        item.liveInstance = true
    if (item && item.hasOwnProperty("hostInstanceKey"))
        item.hostInstanceKey = BarLayoutService.instanceKeyAt(modelData.index)
}
```

Keep this opt-in and instance-key-only so unrelated widgets do not gain accidental API surface.

- [ ] **Step 4: Replace direct tray popup ownership with an upward request chain**

Implement the live request flow in strict order:

1. `TrayIconButton.qml` emits a new signal such as:

```qml
signal trayContextMenuRequested(var trayItem, real clickX, real clickY)
```

and on right click it emits that signal instead of calling `item.display(...)`

2. `TrayPinnedRow.qml` and `TrayFlashRow.qml` forward that signal from their delegates
3. `SystemTrayWidget.qml` declares:

```qml
property string hostInstanceKey: ""
signal trayContextMenuRequested(var trayItem, real clickX, real clickY, string widgetKey, real widgetCenterX)
```

and forwards row-level requests using its own `hostInstanceKey` plus a stable widget-center anchor

4. `BarContent.qml` adds one public entry point, parallel to `openWidgetContextMenu(...)`:

```qml
function openTrayContextMenu(hostInstanceKey, clickX, clickY, widgetCenterX, trayItem) {
    contextMenu.showAt(clickX, clickY, "", 0, "", trayItem, hostInstanceKey, widgetCenterX)
}
```

5. `SystemTrayWidget.qml` calls that bar-level entry through the existing composition owner instead of trying to open a popup itself

Keep host-widget identity separate from tray-item identity throughout this chain. The tray item decides which native rows appear; the host instance key decides which widget `组件设置` should open.

- [ ] **Step 5: Re-run the host-widget harness mode**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh tray-widget-target
```

Expected: PASS.

- [ ] **Step 6: Run the shell-level validation commands**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 7: Commit the live tray context plumbing**

```bash
git add modules/bar/tray/TrayIconButton.qml modules/bar/tray/TrayPinnedRow.qml modules/bar/tray/TrayFlashRow.qml modules/bar/widgets/SystemTrayWidget.qml modules/bar/BarContent.qml modules/bar/BarSection.qml tests/qml/bar/TrayContextMenuHarness.qml
git commit -m "feat: route tray icon right clicks through bar context menu"
```

---

### Task 4: Harden closing behavior and tray-context reset rules

**Files:**
- Modify: `modules/bar/BarContextMenu.qml`
- Modify: `tests/qml/bar/TrayContextMenuHarness.qml`
- Verify: `modules/bar/contextmenu/TrayContextMenuSection.qml`

- [ ] **Step 1: Add failing harness checks for close-reset behavior**

Extend the harness with two more modes:

- `tray-close-reset` — open with tray context, simulate close by clearing `_active`, then expect tray-specific state to be empty on the next background-style open
- `tray-no-menu` — open with a tray item where `hasMenu: false`, then expect no tray divider and no tray rows

- [ ] **Step 2: Run the new harness modes to verify they fail correctly**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh tray-close-reset
sh tests/run-tray-context-menu-harness.sh tray-no-menu
```

Expected: FAIL because tray-context cleanup and `hasMenu` gating are not fully hardened yet.

- [ ] **Step 3: Implement tray-context cleanup in `BarContextMenu.qml`**

When the popup fully closes, clear all tray-specific fields and keep shell-owned behavior intact:

```qml
function _clearTrayContext() {
    _targetTrayItem = null
    _hasTrayContext = false
}

onVisibleChanged: {
    if (!visible) {
        _clearTrayContext()
        BarLayoutService.contextMenuOpen = false
    }
}
```

Also ensure the tray section is gated by both `_hasTrayContext` and `trayItem.hasMenu`.

- [ ] **Step 4: Re-run the complete tray harness suite**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh shell-only
sh tests/run-tray-context-menu-harness.sh tray-inline
sh tests/run-tray-context-menu-harness.sh tray-switch
sh tests/run-tray-context-menu-harness.sh tray-removed
sh tests/run-tray-context-menu-harness.sh tray-widget-target
sh tests/run-tray-context-menu-harness.sh tray-close-reset
sh tests/run-tray-context-menu-harness.sh tray-no-menu
```

Expected: PASS.

- [ ] **Step 5: Run the shell-level validation commands**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 6: Commit the close/reset hardening**

```bash
git add modules/bar/BarContextMenu.qml tests/qml/bar/TrayContextMenuHarness.qml
git commit -m "fix: reset tray context when bar menu closes"
```

---

### Task 5: Final verification sweep

**Files:**
- Verify: `tests/qml/bar/TrayContextMenuHarness.qml`
- Verify: `tests/run-tray-context-menu-harness.sh`
- Verify: `modules/bar/contextmenu/BarContextMenuEntry.qml`
- Verify: `modules/bar/contextmenu/TrayContextMenuSection.qml`
- Verify: `modules/bar/BarContextMenu.qml`
- Verify: `modules/bar/tray/TrayIconButton.qml`
- Verify: `modules/bar/tray/TrayPinnedRow.qml`
- Verify: `modules/bar/tray/TrayFlashRow.qml`
- Verify: `modules/bar/widgets/SystemTrayWidget.qml`
- Verify: `modules/bar/BarContent.qml`
- Verify: `modules/bar/BarSection.qml`

- [ ] **Step 1: Run the full tray harness suite**

Run:

```bash
sh tests/run-tray-context-menu-harness.sh shell-only
sh tests/run-tray-context-menu-harness.sh tray-inline
sh tests/run-tray-context-menu-harness.sh tray-switch
sh tests/run-tray-context-menu-harness.sh tray-removed
sh tests/run-tray-context-menu-harness.sh tray-widget-target
sh tests/run-tray-context-menu-harness.sh tray-close-reset
sh tests/run-tray-context-menu-harness.sh tray-no-menu
```

Expected: PASS.

- [ ] **Step 2: Run the shell load checks**

Run:

```bash
timeout 5 qs --path .
timeout 5 qs -p .
```

Expected: PASS aside from known environment warnings.

- [ ] **Step 3: Manually inspect the live product rules**

Confirm all of these in a live shell session:

- right-clicking a concrete tray icon opens the shell first-level menu
- tray-native rows appear below `组件设置` with a divider in between
- right-clicking another tray icon while the menu is still open switches the tray section in place instead of flashing the whole popup shut
- right-clicking bar background does not show stale tray rows
- tray items without native menus do not create empty tray sections
- if a targeted tray item disappears, shell-owned rows remain usable

- [ ] **Step 4: Confirm scope stayed tight**

Verify these files are unchanged in this wave:

- `services/SystemTrayService.qml`
- `modules/bar/BarWidgetWrapper.qml`

If implementation pressure suggests changing either file, stop and prove in the harness why direct `SystemTrayItem.menu` consumption was insufficient before expanding scope.
