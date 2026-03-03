# Bar Right-Click Context Menu — Design

Date: 2026-03-03

## Problem

The `SettingsToggle` gear widget occupies persistent bar real estate and requires
users to discover the gear button to access layout/settings. A right-click context
menu on the bar is more discoverable and keeps the bar cleaner.

## Goals

- Remove `SettingsToggle.qml` widget entirely
- Expose "布局模式" and "设置" via a right-click context menu on the bar background
- Context menu styled with project theme (`Colors`, `Theme`)
- Esc shortcut continues to close any open panel globally

## Non-Goals

- Per-widget right-click menus (future work)
- Tray or system-level context menus

## Architecture

### Files Changed

| Operation | File | Reason |
|-----------|------|--------|
| Delete | `modules/bar/widgets/SettingsToggle.qml` | Replaced by context menu |
| Create | `modules/bar/BarContextMenu.qml` | PopupWindow-based context menu |
| Modify | `modules/bar/BarContent.qml` | Right-click MouseArea, Esc shortcut, menu instance |
| Modify | `services/BarLayoutService.qml` | Remove `settingsToggle` from `defaultLayout` |

### BarContextMenu.qml

A Quickshell `PopupWindow` that anchors to the bar window surface.

**Properties:**
- `barWindowRef` — reference to the parent `PanelWindow` for anchor
- `function showAt(x, y)` — opens menu at bar-local coordinates

**Positioning strategy (absolute mode):**  
Store click coordinates as a 1×1 anchor item (similar to noctalia-shell's absolute
positioning mode): `anchor.rect` is set to `{x: clickX, y: clickY, width: 1, height: 1}`.
The menu auto-shifts upward when it would overflow below the screen.

**Visual structure:**
```
PopupWindow
  └─ Rectangle (Colors.surface, cornerRadius, 1px border Colors.border, shadow)
       └─ Column (padding: 4, spacing: 2)
            ├─ ContextMenuItem { icon: "\uf0c9"; label: "布局模式"; active: settingsMode }
            └─ ContextMenuItem { icon: "\uf013"; label: "设置" }
```

`ContextMenuItem` is an inline `Item` component (defined in the same file, not
extracted, since it has no other consumers).

**Menu model:**
```js
[
  { icon: "\uf0c9", label: "布局模式",
    onClicked: () => { BarLayoutService.activePanel = BarLayoutService.settingsMode ? "none" : "layout" } },
  { icon: "\uf013", label: "设置",
    onClicked: () => { BarLayoutService.activePanel = "config" } }
]
```

### BarContent.qml Changes

1. Add a full-area `MouseArea` at z:0 (under widgets):
   - `acceptedButtons: Qt.RightButton`
   - `onClicked: contextMenu.showAt(mouseX, mouseY)`
2. Instantiate `BarContextMenu { id: contextMenu }`
3. Move the global `Esc` shortcut here:
   ```qml
   Shortcut {
       sequence: "Escape"
       enabled: BarLayoutService.activePanel !== "none" || contextMenu.visible
       onActivated: {
           BarLayoutService.activePanel = "none"
           contextMenu.visible = false
       }
   }
   ```

### BarLayoutService.qml Changes

Remove `settingsToggle` entry from `defaultLayout`:
```js
// Before
{ id: "settingsToggle", section: "left", alignment: "left", order: 0, enabled: true },
{ id: "workspaceWidget", ... order: 1 ... },

// After
{ id: "workspaceWidget", section: "left", alignment: "left", order: 0, enabled: true },
```

Also remove `"settingsToggle"` from `widgetRegistry` in `BarContent.qml`.

## Interaction Flow

```
Right-click on bar background
  → MouseArea.onClicked
  → contextMenu.showAt(mouseX, mouseY)
  → PopupWindow visible = true, positioned at cursor

Click menu item
  → update BarLayoutService.activePanel
  → contextMenu.visible = false

Click outside menu
  → PopupWindow loses focus → visible = false

Esc key
  → BarLayoutService.activePanel = "none"
  → contextMenu.visible = false
```

## Visual Design

- Background: `Colors.surface` with `opacity: 0.95`
- Border: 1px `Colors.border`
- Corner radius: `Theme.cornerRadius`
- Item height: `Theme.barHeight - Theme.barPadding` (~28px)
- Item padding: 12px horizontal
- Icon + label layout: Row with 8px spacing
- Hover state: `Colors.highlight` at 10% opacity
- Active state bullet for "布局模式" (dim icon when not active)
- Min width: 140px

## Alternatives Considered

**QtQuick.Controls.Menu** — rejected because its default styling diverges from the
project's custom theme and requires extensive style overrides.

**Inline Rectangle overlay** — rejected because it cannot render outside the bar's
layer bounds (no overflow above/below the bar height).
