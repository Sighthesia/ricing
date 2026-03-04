# Widget Picker Panel — Implementation Plan

Date: 2026-03-04  
Design ref: `docs/plans/2026-03-04-widget-picker-design.md`

## Task List

### Task 1 — BarLayoutService: 添加 widgetPickerOpen 状态与 addWidget()

**File**: `services/BarLayoutService.qml`

**Changes**:

1. 在 `contextMenuOpen` 属性后追加：
   ```qml
   // true while the widget picker panel is visible.
   property bool widgetPickerOpen: false
   ```

2. 在 `saveLayout()` 函数后追加：
   ```qml
   // Inserts a new widget instance at the end of the given section.
   function addWidget(widgetId, section) {
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

3. 在退出布局模式时自动关闭 picker（在 `activePanel` 的 `onChanged` 或相关处理中）：
   确保当 `activePanel` 由 `"layout"` 变为其他值时，`widgetPickerOpen = false`。
   推荐在 `WidgetPickerWindow` 的 `visible` 绑定中依赖 `settingsMode`。

**Verification**: `qml -schema` 检查语法无误；属性在其他文件中可通过 `BarLayoutService.widgetPickerOpen` 引用。

---

### Task 2 — BarContextMenu: 添加"小组件库"菜单项

**File**: `modules/bar/BarContextMenu.qml`

**Changes**:

1. 在"设置"菜单项 (`Item { id: settingsItem … }`) 之后追加第三个菜单项：
   ```qml
   Item {
       id: pickerItem
       width: parent.width
       height: Theme.barHeight - Theme.barPadding

       Rectangle {
           id: pickerHighlight
           anchors.fill: parent
           anchors.margins: 2
           radius: Theme.cornerRadius - 2
           color: Colors.surface
           opacity: pickerArea.containsMouse ? 1.0 : 0.0
           Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
       }

       Text {
           anchors.left: parent.left
           anchors.leftMargin: Theme.widgetPadding
           anchors.verticalCenter: parent.verticalCenter
           text: "\uf009"  // icon: grid / widget icon
           font.family: Theme.fontIcon
           font.pixelSize: Theme.fontSizeBody
           color: Colors.text
       }

       Text {
           anchors.left: parent.left
           anchors.leftMargin: Theme.widgetPadding + Theme.fontSizeBody + 6
           anchors.verticalCenter: parent.verticalCenter
           text: "小组件库"
           font.family: Theme.fontFamily
           font.pixelSize: Theme.fontSizeSmall
           color: Colors.text
       }

       MouseArea {
           id: pickerArea
           anchors.fill: parent
           hoverEnabled: true
           cursorShape: Qt.PointingHandCursor
           onClicked: {
               BarLayoutService.widgetPickerOpen = true;
               root._active = false;
           }
       }
   }
   ```

2. 视需要将 `menuContent` 的 `implicitHeight` 适度增加以容纳第三项。

**Verification**: 菜单打开后三个菜单项均渲染，点击"小组件库"后 `widgetPickerOpen === true` 且菜单关闭。

---

### Task 3 — WidgetPickerWindow: 创建小组件选择面板

**File**: `modules/bar/WidgetPickerWindow.qml` (新建)

**核心结构**:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"

PanelWindow {
    id: root

    // Panel sits immediately below the bar
    anchors { top: true; left: true; right: true }
    margins.top: Theme.barHeight
    exclusiveZone: visible ? implicitHeight : 0
    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"

    // Visible only in layout mode while widgetPickerOpen
    visible: BarLayoutService.widgetPickerOpen && BarLayoutService.settingsMode
    onVisibleChanged: if (!visible) BarLayoutService.widgetPickerOpen = false

    implicitHeight: searchBar.height + grid.contentHeight + Theme.barPadding * 2

    // Widget registry — sourced from the same map as BarContent.qml
    // FIXME: promote to BarLayoutService or a dedicated registry singleton in V2
    readonly property var widgetRegistry: ({
        "clock": Qt.resolvedUrl("widgets/Clock.qml"),
        "workspaceWidget": Qt.resolvedUrl("widgets/WorkspaceWidget.qml")
    })

    readonly property var widgetNames: ({
        "clock": "时钟",
        "workspaceWidget": "工作区"
    })

    property string searchQuery: ""

    // Filtered list of widget ids
    readonly property var filteredWidgets: {
        let keys = Object.keys(widgetRegistry);
        if (!searchQuery) return keys;
        let q = searchQuery.toLowerCase();
        return keys.filter(k => (widgetNames[k] || k).toLowerCase().includes(q));
    }

    // Count how many instances of a widget id are in layoutModel
    function countInstances(id) {
        let n = 0;
        for (let i = 0; i < BarLayoutService.layoutModel.count; i++)
            if (BarLayoutService.layoutModel.get(i).id === id) n++;
        return n;
    }

    Rectangle {
        id: panelBg
        anchors.fill: parent
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.barPadding
            spacing: Theme.barPadding

            // --- Search bar ---
            Rectangle {
                id: searchBar
                Layout.fillWidth: true
                height: Theme.barHeight - Theme.barPadding
                radius: Theme.cornerRadius
                color: Colors.surface
                border.color: Colors.border
                border.width: 1

                Text {
                    id: searchPlaceholder
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.widgetPadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: "搜索小组件…"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    visible: searchInput.text.length === 0
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.widgetPadding
                    anchors.rightMargin: Theme.widgetPadding
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                    clip: true
                    onTextChanged: root.searchQuery = text
                    Keys.onEscapePressed: {
                        if (text.length > 0) {
                            text = "";
                        } else {
                            BarLayoutService.widgetPickerOpen = false;
                            BarLayoutService.activePanel = "none";
                        }
                    }
                }
            }

            // --- Widget grid ---
            GridView {
                id: grid
                Layout.fillWidth: true
                // Height driven by content, up to a max of 3 rows
                height: Math.min(contentHeight, cellHeight * 3)
                clip: true
                cellWidth: 160
                cellHeight: 90
                model: root.filteredWidgets

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    // Card
                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.cornerRadius
                        color: cardArea.containsMouse ? Colors.surface : "transparent"
                        border.color: cardArea.containsMouse ? Colors.border : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            // Live widget preview
                            Item {
                                Layout.fillWidth: true
                                height: 46
                                clip: true

                                Loader {
                                    anchors.centerIn: parent
                                    source: root.widgetRegistry[modelData] || ""
                                    // Scale down to fit preview area without clipping
                                    transform: Scale {
                                        xScale: 0.7; yScale: 0.7
                                        origin.x: width / 2; origin.y: height / 2
                                    }
                                }
                            }

                            // Widget name
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.widgetNames[modelData] || modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Colors.textMuted
                                elide: Text.ElideRight
                            }
                        }

                        // Instance count badge
                        Rectangle {
                            id: badge
                            visible: root.countInstances(modelData) > 0
                            width: 18; height: 18
                            radius: 9
                            color: Colors.highlight
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 2
                            anchors.rightMargin: 2

                            Text {
                                anchors.centerIn: parent
                                text: root.countInstances(modelData)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 2
                                color: "white"
                            }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // FIXME: "right" section default is a heuristic — V2 should ask the user
                                BarLayoutService.addWidget(modelData, "right");
                            }
                        }

                        // FIXME: cross-window drag is deferred to V2 — DragHandler requires
                        //        a shared window ancestor between source and drop target.
                    }
                }
            }
        }
    }
}
```

**Verification**: Panel appears below bar in layout mode; grid shows all registered widgets; search filters correctly; click inserts widget at right section end; badge shows count.

---

### Task 4 — shell.qml: 注册 WidgetPickerWindow

**File**: `shell.qml`

**Change**: 在 `ContextMenuBackdrop {}` 后追加：
```qml
WidgetPickerWindow {}
```

并确认 `import "modules/bar"` 已存在（或按项目实际导入路径调整）。

**Verification**: `shell.qml` 解析无误，`WidgetPickerWindow` 实例随 shell 启动。

---

### Task 5 — BarContent.qml: Esc 快捷键覆盖 widgetPickerOpen

**File**: `modules/bar/BarContent.qml`

**Change**: 在现有 `Shortcut` 的 `onActivated` 中追加：
```qml
BarLayoutService.widgetPickerOpen = false;
```

使 Esc 同时关闭菜单、退出布局模式、关闭 picker。

**Verification**: 在 picker 打开时按 Esc，面板关闭且布局模式退出。

---

## Implementation Order

```
Task 1 → Task 2 → Task 3 → Task 4 → Task 5
```

Tasks 1–2 can be executed by the same subagent; Tasks 3–4 are independent after
Task 1; Task 5 is a trivial one-liner added last.

## Success Criteria

- [ ] "小组件库"菜单项出现在右键菜单中，位于"设置"下方
- [ ] 点击后菜单关闭、picker 面板在 bar 下方展开
- [ ] 面板展示所有已注册小组件的实时预览和名称
- [ ] 已添加的小组件显示数量徽标
- [ ] 搜索框可过滤小组件列表
- [ ] 点击小组件卡片将其插入到 bar 右侧区域末尾
- [ ] 退出布局模式后 picker 自动关闭
- [ ] Esc 键关闭 picker 并退出布局模式
