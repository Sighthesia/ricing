# Widget Picker Panel — Design

Date: 2026-03-04

## Problem

In layout mode, there is no way to add new widgets to the bar. Users can only
reorder existing widgets via drag-and-drop.

## Goals

- Add a "小组件库" option to the bar right-click context menu
- Open a full-width panel below the bar showing all available widgets
- Each widget card shows the live rendered widget, its name, and how many instances
  are already on the bar
- User can click a card to insert it at the appropriate bar section end, or drag a
  card onto the bar to insert at a specific position
- Search/filter widget cards by name

## Non-Goals

- Defining/registering new widget types (out of scope; registry is static in BarContent)
- Widget deletion from this panel (deletion is via existing layout mode drag-off logic)
- Multi-monitor support (V1 targets primary screen)

## Architecture

### Files Changed

| Operation | File                                 | Reason                                      |
| --------- | ------------------------------------ | ------------------------------------------- |
| Modify    | `services/BarLayoutService.qml`      | Add `widgetPickerOpen: bool`, `addWidget()` |
| Modify    | `modules/bar/BarContextMenu.qml`     | Add third menu item "小组件库"              |
| Create    | `modules/bar/WidgetPickerWindow.qml` | Full-width PanelWindow picker panel         |
| Modify    | `shell.qml`                          | Register `WidgetPickerWindow {}`            |

### BarLayoutService changes

```qml
// New cross-window bridge: true while widget picker panel is open.
property bool widgetPickerOpen: false

// Adds a new widget instance at the end of the given section.
function addWidget(widgetId, section) {
    // Find max order in target section, insert at order+1.
    let maxOrder = -1;
    for (let i = 0; i < layoutModel.count; i++) {
        let item = layoutModel.get(i);
        if (item.section === section && item.order > maxOrder)
            maxOrder = item.order;
    }
    layoutModel.append({
        id: widgetId,
        section: section,
        alignment: "left",
        order: maxOrder + 1,
        enabled: true
    });
    layoutChanged();
    saveLayout();
}
```

### BarContextMenu.qml changes

Add a third menu item "小组件库" after "设置":

```qml
// Widget picker item
Item {
    id: pickerItem
    width: parent.width
    height: Theme.barHeight - Theme.barPadding
    // [hover Rectangle] [icon \uf009] [Text "小组件库"]
    // onClicked: BarLayoutService.widgetPickerOpen = true; root._active = false
}
```

Also update `implicitWidth` to accommodate the longer label (suggest 160px minimum
is likely sufficient).

### WidgetPickerWindow.qml

A `PanelWindow`:

```
PanelWindow {
  anchors { top: true; left: true; right: true }
  margins.top: Theme.barHeight   // appear directly below bar
  exclusiveZone: panelHeight     // push wayland surfaces down
  WlrLayershell.layer: WlrLayer.Top
  visible: BarLayoutService.widgetPickerOpen && BarLayoutService.settingsMode
  implicitHeight: Theme.barHeight * 5  // ~180px — scrollable if more widgets
```

The panel contains:

1. **Search bar** (`TextInput`, top, identical styling to SettingsPanelContent search)
2. **GridView** of `WidgetPickerCard` delegates
   - `cellWidth`: 160px × `Theme.uiScale`
   - `cellHeight`: 80px × `Theme.uiScale`
   - `model`: filtered list of widget registry keys

#### WidgetPickerCard (inline Component)

```
Item (160 × 80, scaled)
  ├─ Rectangle (background, hoverable)
  ├─ Item (preview area, top 50px)
  │    └─ Loader { source: widgetRegistry[modelData] }
  ├─ Text (widget display name, bottom)
  ├─ Rectangle badge (count > 0 → show count, top-right corner)
  ├─ MouseArea (onClicked → addWidget to "right" section by default)
  └─ DragHandler (drag onto bar)
```

**Count badge**: computed by:
```js
function countInstances(id) {
    let n = 0;
    for (let i = 0; i < BarLayoutService.layoutModel.count; i++)
        if (BarLayoutService.layoutModel.get(i).id === id) n++;
    return n;
}
```

**Display names** (static map for now):
```js
readonly property var widgetNames: ({
    "clock": "时钟",
    "workspaceWidget": "工作区"
})
```

**Search filter**: `GridView.model` is a JS array filtered from registry keys:
```js
property string searchQuery: ""
readonly property var filteredWidgets: {
    let keys = Object.keys(widgetRegistry);
    if (!searchQuery) return keys;
    return keys.filter(k => (widgetNames[k] || k).includes(searchQuery));
}
```

**Click to add**: defaults to inserting at the end of the "right" section.

**Drag to bar**: this is deferred to V2 (complex cross-window DragHandler). V1
only supports click-to-add. A TODO comment is added for the drag interaction.

### Interaction Flow

```
Right-click bar → context menu → "小组件库"
  → BarLayoutService.widgetPickerOpen = true
  → WidgetPickerWindow visible = true
  → context menu closes

Click a widget card
  → addWidget(widgetId, "right")
  → BarLayoutService.layoutChanged → widget appears in bar right section

Search "时针"
  → filteredWidgets updates → GridView filtered to "clock"

Click outside / Esc / exit layout mode
  → widgetPickerOpen = false
  → WidgetPickerWindow hides

Exit layout mode (BarLayoutService.activePanel != "layout")
  → WidgetPickerWindow auto-hides (visible binding)
```

### Closing / Esc

Extend `BarContent.qml` Esc shortcut:
```qml
// Also reset widgetPickerOpen
BarLayoutService.widgetPickerOpen = false;
```

An additional `ContextMenuBackdrop`-style full-screen overlay is NOT needed
because `WidgetPickerWindow` is a full-width PanelWindow — clicking anywhere
outside it (below the panel) passes through normally. The panel closes automatically
when layout mode exits.

## Visual Design

- Background: `Colors.background`, opacity 1.0 (opaque, distinct from bar)
- Top border: 1px `Colors.border`
- Card background hover: `Colors.surface`
- Card preview area: 50px height, scaled to fit
- Card name: `Theme.fontSizeSmall`, `Colors.textMuted`
- Count badge: 16×16px circle, `Colors.highlight`, `Theme.fontSizeSmall`, white text
- Search bar: identical to SettingsPanelContent (reuses `ColorSection`-style styling)
- Panel height: `Theme.barHeight * 4 + 16` (fits 1 row of standard-height cards + search)
- Expand-to-scroll if grid content > panel height

## Alternatives Considered

**Drag-from-picker to Bar (V1)**: Cross-window DragHandler in Quickshell requires
the drag source and drop target to share a common window, which is non-trivial for
two separate PanelWindows. Deferred to V2 with a TODO comment.

**Side-drawer panel**: Considered but rejected by user in favor of full-width.
