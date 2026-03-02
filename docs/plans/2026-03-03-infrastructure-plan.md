# DymicShell 基础设施实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 搭建 DymicShell 项目完整的 QML 骨架，包含所有模块的接口定义和框架代码

**Architecture:** 模块化 QuickShell 项目，config/ 全局配置层 → services/ 数据服务层 → modules/bar/ UI 模块层。Singleton 通过 `pragma Singleton` + QuickShell `Singleton` 类型注册。

**Tech Stack:** QuickShell v0.2.1, QML/Qt Quick, Niri (Wayland compositor), WlrLayershell

---

### Task 1: Palette.qml — 色板常量

**Files:**
- Create: `config/Palette.qml`

**Step 1: Create Palette.qml**

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Dark minimalist palette (from bar-design.md §八)
    readonly property color background:     "#1a1a1a"
    readonly property color surface:        "#252525"
    readonly property color highlight:      "#7aa2f7"
    readonly property real  highlightAlpha: 0.15
    readonly property color text:           "#c0caf5"
    readonly property color textMuted:      "#565f89"
    readonly property color border:         "#3b4261"

    // FIXME: FileView hot-reload hook for matugen integration
    // FileView {
    //     id: colorFile
    //     path: Quickshell.env("HOME") + "/.cache/dymicshell_colors.json"
    //     watchChanges: true
    //     onLoaded: { /* parse JSON and override properties */ }
    //     onFileChanged: colorFile.reload()
    // }
}
```

**Step 2: Verify file exists**

Run: `cat config/Palette.qml`
Expected: File content as above

**Step 3: Commit**

```bash
git add config/Palette.qml
git commit -m "feat(config): add Palette singleton with dark color tokens"
```

---

### Task 2: Theme.qml — 动画 token 与全局尺寸

**Files:**
- Create: `config/Theme.qml`

**Step 1: Create Theme.qml**

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Animation tokens (from bar-design.md §二)
    readonly property QtObject anim: QtObject {
        // Enter: elastic bounce-in for stage entrance, settings ON
        readonly property int enterDuration: 500
        readonly property int enterType: Easing.OutElastic
        readonly property real enterAmplitude: 0.8
        readonly property real enterPeriod: 0.4

        // Exit: exponential snap-out for departure, settings OFF
        readonly property int exitDuration: 220
        readonly property int exitType: Easing.InExpo

        // Move: smooth cubic for position shifts, drag fly-back
        readonly property int moveDuration: 320
        readonly property int moveType: Easing.InOutCubic

        // Highlight: quick pulse for attention flash
        readonly property int highlightDuration: 180
        readonly property int highlightType: Easing.OutQuad
    }

    // Stagger delay per widget index (ms)
    readonly property int staggerDelay: 40

    // Typography
    readonly property string fontFamily: "LXGW WenKai GB Screen"
    readonly property string fontMono: "JetBrainsMono Nerd Font"

    // Dimensions
    readonly property real cornerRadius: 10
    readonly property real barHeight: 36
    readonly property real barPadding: 8
}
```

**Step 2: Commit**

```bash
git add config/Theme.qml
git commit -m "feat(config): add Theme singleton with animation tokens and dimensions"
```

---

### Task 3: NiriService.qml — Niri IPC 服务

**Files:**
- Create: `services/NiriService.qml`

**Step 1: Create NiriService.qml**

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property ListModel workspaces: ListModel {}
    property ListModel windows: ListModel {}

    signal windowsUpdated()

    function updateWorkspaces(workspacesEvent) {
        const list = workspacesEvent.workspaces;
        list.sort((a, b) => a.idx - b.idx);

        workspaces.clear();
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            workspaces.append({
                wsId: String(ws.id),
                idx: ws.idx,
                isActive: ws.is_active,
                name: ws.name || "",
                output: ws.output || ""
            });
        }
    }

    function activateWorkspace(event) {
        const activeId = String(event.id);
        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i);
            const isNowActive = (item.wsId === activeId);
            if (item.isActive !== isNowActive) {
                workspaces.setProperty(i, "isActive", isNowActive);
            }
        }
    }

    function updateWindows(windowList) {
        if (!windowList) return;
        windows.clear();
        for (let i = 0; i < windowList.length; i++) {
            const win = windowList[i];
            windows.append({
                winId: String(win.id),
                title: win.title || "Unknown",
                appId: win.app_id || "unknown",
                workspaceId: String(win.workspace_id) || "",
                isFocused: win.is_focused || false
            });
        }
        windowsUpdated();
    }

    function reloadWindows() {
        niriWindowsFetcher.running = true;
    }

    // Initial window fetch
    Process {
        id: niriWindowsFetcher
        running: true
        command: ["niri", "msg", "-j", "windows"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.updateWindows(JSON.parse(data.trim()));
                } catch (e) {}
            }
        }
    }

    // Event stream listener
    Process {
        id: niriEvents
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());
                    if (event.WorkspacesChanged)
                        root.updateWorkspaces(event.WorkspacesChanged);
                    else if (event.WorkspaceActivated)
                        root.activateWorkspace(event.WorkspaceActivated);
                    else if (event.WindowOpenedOrChanged || event.WindowClosed || event.WindowFocusChanged)
                        root.reloadWindows();
                } catch (e) {
                    console.log("NiriService event parse error:", e);
                }
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add services/NiriService.qml
git commit -m "feat(services): add NiriService singleton with workspace/window IPC"
```

---

### Task 4: BarLayoutService.qml — 布局模型与设置模式

**Files:**
- Create: `services/BarLayoutService.qml`

**Step 1: Create BarLayoutService.qml**

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property bool settingsMode: false
    property ListModel layoutModel: ListModel {}

    // Default layout descriptor (from bar-design.md §三)
    readonly property var defaultLayout: [
        { id: "settingsToggle", section: "left",   alignment: "left",   order: 0, enabled: true },
        { id: "clock",          section: "center", alignment: "center", order: 0, enabled: true }
    ]

    Component.onCompleted: resetLayout()

    function moveWidget(widgetId, toSection, toAlignment, toOrder) {
        for (let i = 0; i < layoutModel.count; i++) {
            if (layoutModel.get(i).id === widgetId) {
                layoutModel.setProperty(i, "section", toSection);
                layoutModel.setProperty(i, "alignment", toAlignment);
                layoutModel.setProperty(i, "order", toOrder);
                break;
            }
        }
        // FIXME: persist to PersistentProperties
    }

    function resetLayout() {
        layoutModel.clear();
        for (let i = 0; i < defaultLayout.length; i++) {
            layoutModel.append(defaultLayout[i]);
        }
    }
}
```

**Step 2: Commit**

```bash
git add services/BarLayoutService.qml
git commit -m "feat(services): add BarLayoutService with layout model and settings mode"
```

---

### Task 5: BarWindow.qml — Bar 窗口壳

**Files:**
- Create: `modules/bar/BarWindow.qml`

**Step 1: Create BarWindow.qml**

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.modules.bar

PanelWindow {
    id: barWindow

    anchors { left: true; top: true; right: true }
    color: "transparent"

    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    BarContent {
        anchors.fill: parent
    }
}
```

**Step 2: Commit**

```bash
git add modules/bar/BarWindow.qml
git commit -m "feat(bar): add BarWindow shell with WlrLayershell"
```

---

### Task 6: BarContent.qml — 三段容器

**Files:**
- Create: `modules/bar/BarContent.qml`

**Step 1: Create BarContent.qml**

```qml
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: barContent

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.barPadding
        anchors.rightMargin: Theme.barPadding
        spacing: 0

        BarSection {
            role: "left"
            Layout.fillHeight: true
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        BarSection {
            role: "center"
            Layout.fillHeight: true
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        BarSection {
            role: "right"
            Layout.fillHeight: true
        }
    }
}
```

**Step 2: Commit**

```bash
git add modules/bar/BarContent.qml
git commit -m "feat(bar): add BarContent with three-section layout"
```

---

### Task 7: BarSection.qml — 单段三对齐子行

**Files:**
- Create: `modules/bar/BarSection.qml`

**Step 1: Create BarSection.qml**

```qml
import QtQuick
import QtQuick.Layouts

Item {
    id: section

    required property string role  // "left", "center", "right"

    implicitWidth: sectionRow.implicitWidth
    implicitHeight: parent ? parent.height : 0

    RowLayout {
        id: sectionRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Align-left sub-row
        Row {
            id: alignLeft
            spacing: 6
            // Widgets with alignment="left" go here
        }

        // Align-center sub-row
        Row {
            id: alignCenter
            spacing: 6
            // Widgets with alignment="center" go here
        }

        // Align-right sub-row
        Row {
            id: alignRight
            spacing: 6
            // Widgets with alignment="right" go here
        }
    }
}
```

**Step 2: Commit**

```bash
git add modules/bar/BarSection.qml
git commit -m "feat(bar): add BarSection with three alignment sub-rows"
```

---

### Task 8: BarWidgetWrapper.qml — 动画合约

**Files:**
- Create: `modules/bar/BarWidgetWrapper.qml`

**Step 1: Create BarWidgetWrapper.qml**

```qml
import QtQuick
import qs.config

Item {
    id: wrapper

    property int staggerIndex: 0
    default property alias content: contentContainer.data

    implicitWidth: contentContainer.implicitWidth
    implicitHeight: contentContainer.implicitHeight

    // Background for highlight pulse
    Rectangle {
        id: pulseBackground
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Palette.highlight
        opacity: 0
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }

    // Staggered enter animation
    opacity: 0
    scale: 0.8
    Component.onCompleted: {
        enterAnimation.start();
    }

    SequentialAnimation {
        id: enterAnimation
        PauseAnimation { duration: wrapper.staggerIndex * Theme.staggerDelay }
        ParallelAnimation {
            NumberAnimation {
                target: wrapper; property: "opacity"
                from: 0; to: 1
                duration: Theme.anim.enterDuration
                easing.type: Theme.anim.enterType
                easing.amplitude: Theme.anim.enterAmplitude
                easing.period: Theme.anim.enterPeriod
            }
            NumberAnimation {
                target: wrapper; property: "scale"
                from: 0.8; to: 1.0
                duration: Theme.anim.enterDuration
                easing.type: Theme.anim.enterType
                easing.amplitude: Theme.anim.enterAmplitude
                easing.period: Theme.anim.enterPeriod
            }
        }
    }

    // Highlight pulse API
    function pulse(count) {
        pulseAnimation.loops = count;
        pulseAnimation.start();
    }

    SequentialAnimation {
        id: pulseAnimation
        property int loops: 1
        loops: pulseAnimation.loops
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: 0; to: Palette.highlightAlpha
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: Palette.highlightAlpha; to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
    }
}
```

**Step 2: Commit**

```bash
git add modules/bar/BarWidgetWrapper.qml
git commit -m "feat(bar): add BarWidgetWrapper with stagger animation and pulse API"
```

---

### Task 9: DragOverlay.qml + widget 占位文件

**Files:**
- Create: `modules/bar/DragOverlay.qml`
- Create: `modules/bar/widgets/SettingsToggle.qml`
- Create: `modules/bar/widgets/Clock.qml`
- Create: `modules/bar/widgets/WorkspaceWidget.qml`

**Step 1: Create DragOverlay.qml**

```qml
import QtQuick

// TODO: implement drag & drop overlay for settings mode
// Ref: bar-design.md §五
Item {
    id: dragOverlay
    visible: false
}
```

**Step 2: Create SettingsToggle.qml**

```qml
import QtQuick

// TODO: implement settings toggle button
// Ref: bar-design.md §六
Item {
    id: settingsToggle
    implicitWidth: 24
    implicitHeight: 24
}
```

**Step 3: Create Clock.qml**

```qml
import QtQuick

// TODO: implement clock widget
Item {
    id: clock
    implicitWidth: 60
    implicitHeight: 24
}
```

**Step 4: Create WorkspaceWidget.qml**

```qml
import QtQuick

// TODO: implement workspace indicator
// Ref: bar-design.md §七 (NiriService integration)
Item {
    id: workspaceWidget
    implicitWidth: 120
    implicitHeight: 24
}
```

**Step 5: Commit**

```bash
git add modules/bar/DragOverlay.qml modules/bar/widgets/
git commit -m "feat(bar): add placeholder files for DragOverlay and widgets"
```

---

### Task 10: shell.qml — 入口文件

**Files:**
- Create: `shell.qml`

**Step 1: Create shell.qml**

```qml
//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.bar

ShellRoot {
    BarWindow {}
}
```

**Step 2: Commit**

```bash
git add shell.qml
git commit -m "feat: add shell.qml entry point"
```

---

### Task 11: Create components/ placeholder

**Files:**
- Create: `components/.gitkeep`

**Step 1: Create .gitkeep**

```bash
mkdir -p components && touch components/.gitkeep
```

**Step 2: Final commit**

```bash
git add components/.gitkeep
git commit -m "chore: add components/ directory placeholder"
```
