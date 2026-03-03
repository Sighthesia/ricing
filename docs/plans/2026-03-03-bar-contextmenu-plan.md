# Bar Right-Click Context Menu — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the `SettingsToggle` gear widget with a right-click context menu on the bar that exposes "布局模式" and "设置" options.

**Architecture:** A `PopupWindow`-based `BarContextMenu.qml` is instantiated in `BarContent.qml`. A transparent `MouseArea` spanning the full bar catches right-clicks and calls `contextMenu.showAt(x, y)`. `SettingsToggle.qml` and its entry in `BarLayoutService.defaultLayout` are removed.

**Tech Stack:** QML, Quickshell (`PopupWindow`, `PanelWindow`), `qs.config` (Theme/Colors), `qs.services` (BarLayoutService)

---

## Task 1: 从 BarLayoutService 移除 settingsToggle

**Files:**
- Modify: `services/BarLayoutService.qml` (lines 30-35)

**Step 1: 编辑 defaultLayout，移除 settingsToggle 条目，并将 workspaceWidget 的 order 调为 0**

```qml
// Before:
readonly property var defaultLayout: [
    { id: "settingsToggle",  section: "left",   alignment: "left", order: 0, enabled: true },
    { id: "workspaceWidget", section: "left",   alignment: "left", order: 1, enabled: true },
    { id: "clock",           section: "center", alignment: "left", order: 0, enabled: true }
]

// After:
readonly property var defaultLayout: [
    { id: "workspaceWidget", section: "left",   alignment: "left", order: 0, enabled: true },
    { id: "clock",           section: "center", alignment: "left", order: 0, enabled: true }
]
```

**Step 2: 手动验证**

启动 shell，确认左侧无齿轮按钮，workspaceWidget 正常显示在左侧第一位。

**Step 3: Commit**

```bash
git add services/BarLayoutService.qml
git commit -m "feat(bar): remove settingsToggle from default layout"
```

---

## Task 2: 从 BarContent 移除 settingsToggle 注册

**Files:**
- Modify: `modules/bar/BarContent.qml`

**Step 1: 从 widgetRegistry 中删除 settingsToggle 条目**

```qml
// Before:
readonly property var widgetRegistry: ({
    "settingsToggle": "widgets/SettingsToggle.qml",
    "clock":          "widgets/Clock.qml",
    "workspaceWidget": "widgets/WorkspaceWidget.qml"
})

// After:
readonly property var widgetRegistry: ({
    "clock":           "widgets/Clock.qml",
    "workspaceWidget": "widgets/WorkspaceWidget.qml"
})
```

**Step 2: Commit**

```bash
git add modules/bar/BarContent.qml
git commit -m "feat(bar): remove settingsToggle from widget registry"
```

---

## Task 3: 删除 SettingsToggle.qml

**Files:**
- Delete: `modules/bar/widgets/SettingsToggle.qml`

**Step 1: 删除文件**

```bash
rm modules/bar/widgets/SettingsToggle.qml
```

**Step 2: Commit**

```bash
git add -A modules/bar/widgets/SettingsToggle.qml
git commit -m "feat(bar): delete SettingsToggle widget"
```

---

## Task 4: 创建 BarContextMenu.qml

**Files:**
- Create: `modules/bar/BarContextMenu.qml`

**Step 1: 创建组件文件，完整内容如下**

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Right-click context menu for the bar background.
// Opened via showAt(x, y) where x/y are BarContent-local coordinates.
PopupWindow {
    id: root

    // Caller must set this to barWindow (PanelWindow) for anchor.
    required property var barWindowRef

    visible: false
    color: "transparent"

    // Use the bar window as the anchor surface.
    anchor.item: barWindowRef

    // 1×1 anchor rect is the "absolute cursor position" pattern:
    // the menu positions itself at (clickX, clickY) within the anchor window.
    anchor.rect.x: _clickX
    anchor.rect.y: _clickY
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: menuColumn.implicitWidth + 2 * _padding
    implicitHeight: menuColumn.implicitHeight + 2 * _padding

    property real _clickX: 0
    property real _clickY: 0
    readonly property real _padding: 4
    readonly property real _itemHeight: Theme.barHeight - Theme.barPadding
    readonly property real _minWidth: 140

    // Opens menu at BarContent-local coordinates.
    function showAt(x, y) {
        _clickX = x;
        // Shift menu above bar if it would overflow below bar top edge.
        // Bar is always "top" in this project; menu should appear above (negative y).
        _clickY = -(implicitHeight + 4);
        visible = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.surface
        opacity: 0.97
        radius: Theme.cornerRadius
        border.color: Colors.border
        border.width: 1

        // Subtle drop shadow via layered rectangles.
        layer.enabled: true

        Column {
            id: menuColumn
            anchors.centerIn: parent
            spacing: 2
            width: Math.max(root._minWidth, implicitWidth)

            // --- Layout mode item ---
            Item {
                id: layoutItem
                width: parent.width
                height: root._itemHeight

                readonly property bool isActive: BarLayoutService.settingsMode

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.cornerRadius - 2
                    color: Colors.highlight
                    opacity: layoutHover.containsMouse ? 0.12 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.highlightDuration }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 8

                    Text {
                        text: "\uf0c9"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: layoutItem.isActive ? Colors.accent : Colors.text
                        opacity: layoutItem.isActive ? 1.0 : 0.7
                    }

                    Text {
                        text: layoutItem.isActive ? "退出布局模式" : "布局模式"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                MouseArea {
                    id: layoutHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        BarLayoutService.activePanel =
                            BarLayoutService.settingsMode ? "none" : "layout";
                        root.visible = false;
                    }
                }
            }

            // --- Settings item ---
            Item {
                id: settingsItem
                width: parent.width
                height: root._itemHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.cornerRadius - 2
                    color: Colors.highlight
                    opacity: settingsHover.containsMouse ? 0.12 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.highlightDuration }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 8

                    Text {
                        text: "\uf013"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text
                        opacity: 0.7
                    }

                    Text {
                        text: "设置"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                MouseArea {
                    id: settingsHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        BarLayoutService.activePanel = "config";
                        root.visible = false;
                    }
                }
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add modules/bar/BarContextMenu.qml
git commit -m "feat(bar): add BarContextMenu PopupWindow component"
```

---

## Task 5: 修改 BarContent.qml — 接入右键菜单

**Files:**
- Modify: `modules/bar/BarContent.qml`

**Step 1: 在顶部 `import` 区域添加（如果 qs.modules.bar 不包含的话，确认即可，同目录组件无需额外 import）**

`BarContextMenu` 与 `BarContent` 同处 `modules/bar/`，Quickshell 的 singleton 扫描会自动识别，无需额外 import。

**Step 2: 在 `Item { id: barContent` 内追加以下内容（在最后一个子元素 `DragOverlay` 之后）**

```qml
    // Right-click context menu — opened on bar background right-click.
    BarContextMenu {
        id: contextMenu
        // barWindowRef is set after component completion to avoid forward-reference.
        Component.onCompleted: {
            // Walk up to find the PanelWindow (BarWindow).
            let p = barContent.parent;
            while (p && !(p instanceof PanelWindow)) p = p.parent;
            barWindowRef = p;
        }
    }

    // Transparent full-bar MouseArea at z:0 (below widgets, above nothing).
    // Only captures right-button clicks on empty bar space.
    MouseArea {
        id: barRightClick
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.showAt(mouse.x, mouse.y);
            }
        }
    }

    // Global Esc: closes any active panel and the context menu.
    Shortcut {
        sequence: "Escape"
        enabled: BarLayoutService.activePanel !== "none" || contextMenu.visible
        onActivated: {
            BarLayoutService.activePanel = "none";
            contextMenu.visible = false;
        }
    }
```

**Step 3: 手动验证交互**

- 右键点击 bar 空白处 → 菜单弹出，位于鼠标上方
- 点击"布局模式" → DragOverlay 出现，菜单关闭
- 再次右键 → 菜单"布局模式"文字变为"退出布局模式"
- 点击"退出布局模式" → DragOverlay 消失
- 右键 → 点击"设置" → 设置面板打开
- 按 Esc → 面板关闭

**Step 4: Commit**

```bash
git add modules/bar/BarContent.qml
git commit -m "feat(bar): wire right-click context menu into BarContent"
```

---

## Task 6: 验证 PopupWindow anchor 实际定位

> `PopupWindow` 在 Quickshell 中的绝对定位行为依赖 compositor 实现。  
> 如果菜单位置不正确（例如锚定到错误的角），按以下步骤调试：

**Step 1: 检查 `_clickY` 计算**

若菜单出现在 bar 内部（而非上方），将 `showAt` 中的 y 计算改为：

```qml
// Position above the bar (negative offset from bar top edge).
_clickY = -(root.implicitHeight + 4);
```

若菜单应出现在 bar 下方（bottom bar），改为：

```qml
_clickY = Theme.barHeight + 4;
```

**Step 2: 检查 barWindowRef 是否正确赋值**

在 `BarContextMenu.onVisibleChanged` 里临时加一行 `console.log("barWindowRef:", barWindowRef)` 验证。

**Step 3: Commit（如有修正）**

```bash
git add modules/bar/BarContextMenu.qml modules/bar/BarContent.qml
git commit -m "fix(bar): correct context menu anchor positioning"
```
