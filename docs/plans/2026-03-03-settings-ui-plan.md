# 设置 UI 面板实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现设置 UI 面板：Tab 切换 SettingsToggle、PanelWindow 设置面板、颜色/Slider/Toggle/位置控件，直接写入 SettingsService。

**Architecture:** BarLayoutService 新增 `activePanel` 字段；`settingsMode` 改为计算属性保向后兼容；SettingsToggle 升级为 Tab 切换；新增 SettingsPanelWindow + 三个 Section 组件。

**Tech Stack:** Quickshell (PanelWindow, WlrLayershell), QML (Column/Row/Rectangle/TextInput/MouseArea), SettingsService

**Design Doc:** `docs/plans/2026-03-03-settings-ui-design.md`

**Prerequisites:** SettingsService 已实现（`services/SettingsService.qml` 存在）

---

## Task 1: 升级 BarLayoutService — activePanel + computed settingsMode

**Files:**
- Modify: `services/BarLayoutService.qml`

**Step 1: 将 `property bool settingsMode` 替换为 `activePanel` + 计算属性**

找到 BarLayoutService.qml 第 10 行（`property bool settingsMode: false`），替换为：

```qml
    // Panel state: "none" | "layout" | "config"
    property string activePanel: "none"

    // Computed alias — keeps all existing DragOverlay/BarSection bindings unchanged
    readonly property bool settingsMode: activePanel === "layout"
```

**Step 2: 验证现有 settingsMode 引用仍然有效**

```bash
grep -rn "settingsMode" modules/bar --include="*.qml" | wc -l
```

期望：仍然有多行命中（说明引用存在），但不是 0（没有被意外删除）。

**Step 3: Commit**

```bash
git add services/BarLayoutService.qml
git commit -m "refactor(bar): replace settingsMode bool with activePanel string enum"
```

---

## Task 2: 升级 SettingsToggle — Tab 条 + activePanel 逻辑

**Files:**
- Modify: `modules/bar/widgets/SettingsToggle.qml`

**Step 1: 完整替换 SettingsToggle.qml**

新的 SettingsToggle 包含：
1. 原有齿轮图标 + hover/pulse 逻辑（保留）
2. 新增 Tab 行（`activePanel !== "none"` 时渐显）

```qml
import QtQuick
import qs.config
import qs.services

Item {
    id: settingsToggle

    // Expand width to accommodate tab bar when panel is open
    readonly property bool panelOpen: BarLayoutService.activePanel !== "none"

    implicitWidth: panelOpen
        ? tabRow.implicitWidth + Theme.widgetSpacing + gearBtn.implicitWidth
        : gearBtn.implicitWidth
    implicitHeight: Theme.barHeight - Theme.barPadding

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic }
    }

    // Tab bar: visible when panel is open
    Row {
        id: tabRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 4
        opacity: settingsToggle.panelOpen ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Easing.OutQuad }
        }

        // Layout tab
        Rectangle {
            id: layoutTab
            width: 52; height: 24
            radius: Theme.cornerRadius - 4
            color: BarLayoutService.activePanel === "layout" ? Colors.highlight : Colors.surface
            opacity: BarLayoutService.activePanel === "layout" ? 0.9 : 0.6

            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            Text {
                anchors.centerIn: parent
                text: "布局"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: BarLayoutService.activePanel = "layout"
            }
        }

        // Config tab
        Rectangle {
            id: configTab
            width: 52; height: 24
            radius: Theme.cornerRadius - 4
            color: BarLayoutService.activePanel === "config" ? Colors.highlight : Colors.surface
            opacity: BarLayoutService.activePanel === "config" ? 0.9 : 0.6

            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

            Text {
                anchors.centerIn: parent
                text: "设置"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: BarLayoutService.activePanel = "config"
            }
        }
    }

    // Gear button area
    Item {
        id: gearBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Theme.barHeight - Theme.barPadding
        implicitHeight: Theme.barHeight - Theme.barPadding

        // Background rectangle: reveals on hover and any panel mode
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Colors.highlight
            opacity: settingsToggle.panelOpen
                ? Colors.highlightAlpha
                : (hoverArea.containsMouse ? 0.08 : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: settingsToggle.panelOpen
                        ? Easing.OutExpo
                        : Easing.InExpo
                }
            }
        }

        // Gear icon
        Text {
            id: icon
            anchors.centerIn: parent
            text: "\uf013"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeIcon
            color: Colors.text

            rotation: settingsToggle.panelOpen ? 45 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: settingsToggle.panelOpen
                        ? Theme.anim.enterDuration : Theme.anim.exitDuration
                    easing.type: settingsToggle.panelOpen
                        ? Easing.OutElastic : Easing.InExpo
                    easing.amplitude: settingsToggle.panelOpen
                        ? Theme.anim.enterAmplitude : 1.0
                    easing.period: settingsToggle.panelOpen
                        ? Theme.anim.enterPeriod : 0.3
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (BarLayoutService.activePanel !== "none") {
                    BarLayoutService.activePanel = "none"
                } else {
                    // Default: open layout tab first
                    BarLayoutService.activePanel = "layout"
                }
            }
        }
    }

    // Periodic pulse in any panel mode (every 3s)
    Timer {
        id: pulseTimer
        interval: Theme.pulseInterval
        repeat: true
        running: settingsToggle.panelOpen

        onTriggered: {
            if (settingsToggle.parent && settingsToggle.parent.pulse) {
                settingsToggle.parent.pulse(1)
            }
        }
    }

    // Global Esc always closes panel
    Shortcut {
        sequence: "Escape"
        enabled: settingsToggle.panelOpen
        onActivated: BarLayoutService.activePanel = "none"
    }
}
```

**Step 2: 验证交互逻辑**

手动检查点（启动 shell 后）：
- 点击齿轮 → 出现"布局"和"设置"两个 Tab + 齿轮旋转 45°
- 点击"布局" → DragOverlay 出现（现有行为）
- 点击"设置" → Tab 激活（面板等 Task 4 后验证）
- 再次点击齿轮 → 关闭，Tab 消失

**Step 3: Commit**

```bash
git add modules/bar/widgets/SettingsToggle.qml
git commit -m "feat(bar): upgrade SettingsToggle with tab bar for layout/config modes"
```

---

## Task 3: 创建基础控件组件

**Files:**
- Create: `modules/bar/settings/ColorSection.qml`
- Create: `modules/bar/settings/SliderSection.qml`
- Create: `modules/bar/settings/BehaviorSection.qml`

### 3a: SliderSection.qml（可复用 Slider 行）

```qml
import QtQuick
import qs.config

// A single labeled slider row bound to an external real property.
// Usage:
//   SliderSection {
//     label: "高度"
//     value: SettingsService.data.bar.height
//     from: 24; to: 60; stepSize: 1
//     onValueChanged: SettingsService.data.bar.height = value
//   }
Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property string unit: ""

    signal valueChanged(real newValue)

    implicitWidth: parent.width
    implicitHeight: 32

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            width: 64
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
        }

        // Track
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 64 - 40 - 2 * parent.spacing
            height: 4

            Rectangle {
                id: track
                anchors.fill: parent
                radius: 2
                color: Colors.surface
            }

            Rectangle {
                width: handle.x + handle.width / 2
                height: 4
                radius: 2
                color: Colors.highlight
            }

            Rectangle {
                id: handle
                width: 14; height: 14
                radius: 7
                color: Colors.highlight
                anchors.verticalCenter: parent.verticalCenter
                x: {
                    let ratio = (root.value - root.from) / (root.to - root.from)
                    return ratio * (track.width - width)
                }

                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: track.width - handle.width
                    cursorShape: Qt.SizeHorCursor
                    onPositionChanged: {
                        if (drag.active) {
                            let ratio = handle.x / (track.width - handle.width)
                            let rawVal = root.from + ratio * (root.to - root.from)
                            let stepped = Math.round(rawVal / root.stepSize) * root.stepSize
                            let clamped = Math.max(root.from, Math.min(root.to, stepped))
                            root.valueChanged(clamped)
                        }
                    }
                }
            }
        }

        Text {
            width: 40
            anchors.verticalCenter: parent.verticalCenter
            text: root.value.toFixed(root.stepSize < 1 ? 2 : 0) + root.unit
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.text
            horizontalAlignment: Text.AlignRight
        }
    }
}
```

### 3b: ColorSection.qml（颜色行：标签 + 色块 + Hex 输入）

```qml
import QtQuick
import qs.config

// A color picker row with preset swatches and hex text input.
// Usage:
//   ColorSection {
//     label: "强调色"
//     value: SettingsService.data.appearance.accentColor
//     onValueChanged: SettingsService.data.appearance.accentColor = value
//   }
Item {
    id: root

    property string label: ""
    property string value: "#ffffff"

    signal valueChanged(string newValue)

    implicitWidth: parent.width
    implicitHeight: 36

    // Validation: only accept #RRGGBB format
    function isValidHex(s) {
        return /^#[0-9a-fA-F]{6}$/.test(s)
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // Label
        Text {
            width: 64
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
        }

        // Current color preview swatch
        Rectangle {
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: root.isValidHex(root.value) ? root.value : "#7aa2f7"
            border.color: Colors.border
            border.width: 1
        }

        // Hex text input
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 90; height: 24
            radius: 4
            color: Colors.surface
            border.color: hexInput.activeFocus ? Colors.highlight : Colors.border
            border.width: 1

            TextInput {
                id: hexInput
                anchors.fill: parent
                anchors.margins: 4
                text: root.value.toUpperCase()
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.text
                maximumLength: 7
                selectByMouse: true
                onEditingFinished: {
                    let v = text.startsWith("#") ? text : "#" + text
                    if (root.isValidHex(v)) {
                        root.valueChanged(v.toLowerCase())
                    } else {
                        // Revert to current value on invalid input
                        text = root.value.toUpperCase()
                    }
                }
                // Sync display when external value changes
                onActiveFocusChanged: {
                    if (!activeFocus) text = root.value.toUpperCase()
                }
            }
        }
    }
}
```

### 3c: BehaviorSection.qml（Toggle + 位置选择）

```qml
import QtQuick
import qs.config
import qs.services

// Bar behavior controls: position selector and auto-hide toggle
Item {
    id: root

    implicitWidth: parent.width
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 4

        // Position selector row
        Item {
            width: parent.width
            height: 32

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    width: 64
                    anchors.verticalCenter: parent.verticalCenter
                    text: "位置"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [{ value: "top", label: "顶部" }, { value: "bottom", label: "底部" }]

                        delegate: Rectangle {
                            width: 52; height: 24
                            radius: Theme.cornerRadius - 4
                            color: SettingsService.data.bar.position === modelData.value
                                ? Colors.highlight : Colors.surface
                            opacity: SettingsService.data.bar.position === modelData.value ? 0.9 : 0.6

                            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Colors.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsService.data.bar.position = modelData.value
                            }
                        }
                    }
                }
            }
        }

        // Auto-hide toggle row
        Item {
            width: parent.width
            height: 32

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    width: 64
                    anchors.verticalCenter: parent.verticalCenter
                    text: "自动隐藏"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                // Toggle switch
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 24

                    Rectangle {
                        id: toggleTrack
                        anchors.fill: parent
                        radius: 12
                        color: SettingsService.data.barBehavior.autoHide
                            ? Colors.highlight : Colors.surface
                        opacity: 0.8

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    Rectangle {
                        id: toggleKnob
                        width: 18; height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        x: SettingsService.data.barBehavior.autoHide ? 22 : 3

                        Behavior on x {
                            NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsService.data.barBehavior.autoHide =
                            !SettingsService.data.barBehavior.autoHide
                    }
                }
            }
        }
    }
}
```

**Step 4: Commit**

```bash
git add modules/bar/settings/
git commit -m "feat(settings-ui): add ColorSection, SliderSection, BehaviorSection controls"
```

---

## Task 4: 创建 SettingsPanelContent.qml 和 SettingsPanelWindow.qml

**Files:**
- Create: `modules/bar/settings/SettingsPanelContent.qml`
- Create: `modules/bar/SettingsPanelWindow.qml`

### 4a: SettingsPanelContent.qml

```qml
import QtQuick
import qs.config
import qs.services
import "."

// Scrollable settings content with three sections.
// Designed to be embedded inside SettingsPanelWindow.
Item {
    id: root

    implicitWidth: col.implicitWidth
    implicitHeight: Math.min(col.implicitHeight, 480)

    // Helper to create section header text
    component SectionHeader: Text {
        leftPadding: 12
        topPadding: 8
        bottomPadding: 4
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: Colors.textMuted
        text: ""
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true

        Column {
            id: col
            width: root.implicitWidth
            spacing: 2

            // ── Appearance ─────────────────────────
            SectionHeader { text: "外观" }

            ColorSection {
                label: "强调色"
                value: SettingsService.data.appearance.accentColor
                onValueChanged: SettingsService.data.appearance.accentColor = newValue
            }

            ColorSection {
                label: "背景色"
                value: SettingsService.data.appearance.backgroundColor
                onValueChanged: SettingsService.data.appearance.backgroundColor = newValue
            }

            ColorSection {
                label: "表面色"
                value: SettingsService.data.appearance.surfaceColor
                onValueChanged: SettingsService.data.appearance.surfaceColor = newValue
            }

            // ── Bar ────────────────────────────────
            SectionHeader { text: "Bar" }

            SliderSection {
                label: "高度"
                value: SettingsService.data.bar.height
                from: 24; to: 60; stepSize: 1; unit: "px"
                onValueChanged: SettingsService.data.bar.height = newValue
            }

            SliderSection {
                label: "透明度"
                value: SettingsService.data.bar.backgroundOpacity
                from: 0.0; to: 1.0; stepSize: 0.05
                onValueChanged: SettingsService.data.bar.backgroundOpacity = newValue
            }

            SliderSection {
                label: "动画速度"
                value: SettingsService.data.animation.speedFactor
                from: 0.2; to: 3.0; stepSize: 0.1; unit: "×"
                onValueChanged: SettingsService.data.animation.speedFactor = newValue
            }

            // ── Behavior ───────────────────────────
            SectionHeader { text: "行为" }

            BehaviorSection {}

            // Bottom padding
            Item { width: 1; height: 8 }
        }
    }
}
```

### 4b: SettingsPanelWindow.qml

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import "./settings"

PanelWindow {
    id: panelWindow

    // Appear at top-right, below the Bar
    anchors { top: true; right: true }

    // Only visible when config tab is active
    visible: BarLayoutService.activePanel === "config"

    // Height auto-fits content; width fixed
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 16

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Panel background
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        color: Colors.background
        radius: Theme.cornerRadius
        border.color: Colors.border
        border.width: 1
        opacity: 0.97

        // Panel shadow simulation via layered rectangles
        layer.enabled: true
    }

    SettingsPanelContent {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 8
        }
    }

    // Enter animation
    opacity: visible ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.OutCubic }
    }
}
```

**Step 5: Commit**

```bash
git add modules/bar/settings/SettingsPanelContent.qml modules/bar/SettingsPanelWindow.qml
git commit -m "feat(settings-ui): add SettingsPanelContent and SettingsPanelWindow"
```

---

## Task 5: 挂载 SettingsPanelWindow 到 shell.qml

**Files:**
- Modify: `shell.qml`
- Modify: `modules/bar/qmldir` (如不存在则在 modules/bar/ 下隐式注册)

**Step 1: 更新 shell.qml**

```qml
//@ pragma UseQApplication
import Quickshell
import qs.modules.bar

ShellRoot {
    BarWindow {}
    SettingsPanelWindow {}
}
```

**Step 2: 验证 shell 启动无报错**

```bash
quickshell -p /path/to/DymicShell 2>&1 | grep -i "error\|warning\|cannot" | head -20
```

期望：无 SettingsPanelWindow 或 SettingsPanelContent 相关错误。

**Step 3: 完整功能验证清单**

- [ ] ① 点击齿轮 → Tab Bar 显示，齿轮旋转 45°
- [ ] ② Tab[布局] → DragOverlay 可见，可拖拽 widget
- [ ] ③ Tab[设置] → SettingsPanel 在右上角弹出
- [ ] ④ 拖动"高度" Slider → Bar 高度实时变化
- [ ] ⑤ 拖动"透明度" Slider → Bar 背景透明度实时变化
- [ ] ⑥ 编辑"强调色" Hex 输入框（Enter 确认）→ 颜色变化
- [ ] ⑦ 修改后 500ms 内 `~/.config/dymicshell/settings.json` 更新
- [ ] ⑧ 重启 shell → 设置持久化恢复
- [ ] ⑨ 按 Esc → 面板关闭

**Step 4: 最终 Commit**

```bash
git add shell.qml
git commit -m "feat(settings-ui): mount SettingsPanelWindow in shell root"
```

---

## 注意事项

1. **QML 模块注册**：Quickshell 根据目录结构自动注册模块。`modules/bar/settings/` 目录下的 QML 文件作为相对路径 `"."` 引用，在 `SettingsPanelContent.qml` 中用 `import "."` 导入同目录控件。
2. **颜色属性写入**：`SettingsService.data.appearance.accentColor` 是 `string` 类型，直接赋值 hex 字符串即可触发 JsonAdapter 保存流程。
3. **Slider 拖拽**：Slider 未使用 Qt 内置 `Slider` 控件（避免样式冲突），使用 MouseArea drag 实现，drag 过程中 stepSize 舍入在 JS 中完成。
4. **PanelWindow 位置**：`anchors.top: true; anchors.right: true` 使面板贴右上角。`exclusiveZone` 不设置（面板悬浮，不推挤内容）。
