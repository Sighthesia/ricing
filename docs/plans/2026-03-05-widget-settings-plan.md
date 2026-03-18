# Widget Settings Panel — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Right-clicking a bar widget opens an extended context menu; "组件设置" auto-enters layout mode and opens a floating bubble panel below the widget with universal appearance overrides, a per-widget config slot, and lifecycle actions (delete, copy, import/export).

**Architecture:** Service-layer state in `BarLayoutService` + new `WidgetConfigService` singleton. `BarContextMenu` gains a conditional widget section. A new `WidgetSettingsPanel` (`PopupWindow`) is instantiated inside `BarContent` and anchors below the bar at the widget's centre X. Per-widget config is persisted to `.state/widget-config.json`.

**Tech Stack:** Quickshell QML, Quickshell.Io (Process + PersistentProperties), Qt Quick

---

## Task 1 — Extend `BarLayoutService`

**Files:** Modify `services/BarLayoutService.qml`

### Step 1: Add widget settings state properties

After `property bool widgetPickerOpen: false`, insert:

```qml
// Which widget instance is currently being configured (instanceKey format: "{widgetId}_{n}").
// Empty string means no widget is selected.
property string activeWidgetInstanceKey: ""

// Bar-coordinate X of the centre of the widget under configuration.
// Used by WidgetSettingsPanel to position itself.
property real widgetSettingsX: 0

// True while the widget settings panel is visible.
property bool widgetSettingsPanelOpen: false
```

### Step 2: Add `instanceKeyAt` helper function

After the `isSamePlacement` function, insert:

```qml
// Returns the stable instance key for the widget at layoutModel[modelIndex].
// Key format: "{widgetId}_{n}" where n counts how many prior entries share the same widgetId.
function instanceKeyAt(modelIndex) {
    if (modelIndex < 0 || modelIndex >= layoutModel.count) return "";
    let targetId = layoutModel.get(modelIndex).id;
    let n = 0;
    for (let i = 0; i < modelIndex; i++) {
        if (layoutModel.get(i).id === targetId) n++;
    }
    return targetId + "_" + n;
}
```

### Step 3: Add `removeWidget` helper function

After `addWidget`, insert:

```qml
// Removes the widget instance identified by instanceKey from the layout model.
// instanceKey must match what instanceKeyAt() would return for that entry.
function removeWidget(instanceKey) {
    for (let i = 0; i < layoutModel.count; i++) {
        if (instanceKeyAt(i) === instanceKey) {
            layoutModel.remove(i);
            layoutChanged();
            saveLayout();
            return;
        }
    }
}
```

### Step 4: Guard — close panel when layout mode exits

In `onActivePanelChanged` (or add a new binding):

```qml
onSettingsModeChanged: {
    if (!settingsMode) {
        widgetSettingsPanelOpen = false;
        activeWidgetInstanceKey = "";
    }
}
```

**Verify:** Hot-reload the shell; check there are no QML warnings in journal.

---

## Task 2 — Create `WidgetConfigService`

**Files:** Create `services/WidgetConfigService.qml`

### Step 1: Create the singleton

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Persists per-widget-instance appearance overrides and future functional config.
// Storage: .state/widget-config.json
// Access: WidgetConfigService.getAppearance(instanceKey) → object | null
//         WidgetConfigService.setAppearance(instanceKey, patch)
//         WidgetConfigService.removeConfig(instanceKey)
Singleton {
    id: root

    readonly property string _configDir:  Quickshell.workingDirectory + "/.state"
    readonly property string _configFile: _configDir + "/widget-config.json"

    // In-memory store: instanceKey → { appearance: {…}, widgetConfig: {} }
    property var _store: ({})

    signal storeChanged

    Component.onCompleted: _fileReader.running = true

    // Read saved config from disk on startup
    Process {
        id: _fileReader
        command: ["cat", root._configFile]
        stdout: SplitParser {
            onRead: function(data) {
                let trimmed = data.trim();
                if (trimmed !== "") {
                    try { root._store = JSON.parse(trimmed); } catch (e) {}
                }
            }
        }
    }

    // Debounced disk write — batches rapid successive changes
    Timer {
        id: _saveTimer
        interval: 500
        repeat: false
        onTriggered: root._flushToDisk()
    }

    Process {
        id: _fileWriter
        stdinEnabled: true
        command: ["sh", "-c",
            "mkdir -p '" + root._configDir + "' && cat > '" + root._configFile + "'"]
    }

    function _flushToDisk() {
        _fileWriter.running = false;
        _fileWriter.running = true;
        _fileWriter.write(JSON.stringify(root._store, null, 2) + "\n");
    }

    // Returns the appearance override object for instanceKey, or empty object if none.
    function getAppearance(instanceKey) {
        let entry = _store[instanceKey];
        return (entry && entry.appearance) ? entry.appearance : {};
    }

    // Merges patch into the appearance overrides for instanceKey and schedules a save.
    function setAppearance(instanceKey, patch) {
        let store = root._store;
        if (!store[instanceKey]) store[instanceKey] = { appearance: {}, widgetConfig: {} };
        let app = store[instanceKey].appearance;
        let keys = Object.keys(patch);
        for (let i = 0; i < keys.length; i++) app[keys[i]] = patch[keys[i]];
        root._store = store;
        root.storeChanged();
        _saveTimer.restart();
    }

    // Removes all config for instanceKey (used on widget deletion).
    function removeConfig(instanceKey) {
        let store = root._store;
        delete store[instanceKey];
        root._store = store;
        root.storeChanged();
        _saveTimer.restart();
    }

    // Returns a portable export object for the given instanceKey.
    function exportPayload(widgetId, instanceKey) {
        let entry = _store[instanceKey] || { appearance: {}, widgetConfig: {} };
        return {
            widgetId: widgetId,
            appearance: entry.appearance || {},
            widgetConfig: entry.widgetConfig || {}
        };
    }
}
```

### Step 2: Register in `shell.qml`

Open `shell.qml`.  Add `import qs.services` if not already present.  The file uses `Variants` or a top-level `QtObject`; add `WidgetConfigService {}` alongside the other singletons if explicit instantiation is needed. (Quickshell singletons are auto-instantiated on import — verify by checking how `BarLayoutService` is declared; if it needs no manual instantiation, skip this step.)

**Verify:** Hot-reload; `console.log(WidgetConfigService.getAppearance("test"))` in any running QML file should return `{}` without errors.

---

## Task 3 — Extend `BarContextMenu`

**Files:** Modify `modules/bar/BarContextMenu.qml`

### Step 1: Add widget-context properties

After `property bool _active: false`, add:

```qml
// Set by BarWidgetWrapper right-click; "" means bar-background right-click.
property string _targetWidgetKey: ""
// Bar-coord X of the widget centre; forwarded to LayoutService on panel open.
property real _targetWidgetCenterX: 0
// Human-readable widget type label shown in the menu header.
property string _targetWidgetLabel: ""
```

### Step 2: Extend `showAt` signature

Replace the existing `showAt` function:

```qml
// Open menu at BarContent-local coords.
// instanceKey / widgetCenterX / widgetLabel are optional — supply for widget right-click.
function showAt(x, _y, instanceKey, widgetCenterX, widgetLabel) {
    _clickX = x;
    _targetWidgetKey = instanceKey || "";
    _targetWidgetCenterX = widgetCenterX || 0;
    _targetWidgetLabel = widgetLabel || "";
    anchor.updateAnchor();
    BarLayoutService.contextMenuOpen = true;
    _active = true;
}
```

### Step 3: Reset widget context on close

In `on_ActiveChanged`, when `!_active`, add:

```qml
if (!_active) {
    _targetWidgetKey = "";
    _targetWidgetCenterX = 0;
    _targetWidgetLabel = "";
}
```

### Step 4: Inject widget section into `menuColumn`

After the closing `}` of `s_settingsItem`, add inside `menuColumn`:

```qml
// --- Widget section separator (visible only on widget right-click) ---
Rectangle {
    visible: root._targetWidgetKey !== ""
    width: parent.width - 8
    anchors.horizontalCenter: parent.horizontalCenter
    height: 1
    color: Colors.border
    opacity: 0.5
}

// --- "Component settings" item ---
StaggerItem {
    id: s_widgetSettings
    visible: root._targetWidgetKey !== ""
    delay: SettingsService.data.animation.staggerLevel1BaseDelay
         + SettingsService.data.animation.staggerLevel1Step * 2
    exitDelay: 0
    width: parent.width
    height: visible ? Theme.barHeight - Theme.barPadding : 0

    HoverRevealHighlight {
        anchors.fill: parent; anchors.margins: 1
        radius: Theme.cornerRadius - 2
        hovered: widgetSettingsArea.containsMouse
        highlightColor: Colors.highlight; highlightOpacity: 0.12
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: Theme.widgetPadding
        spacing: 8
        Text {
            text: "\uf085"
            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeIcon
            color: Colors.text; opacity: 0.7
        }
        Text {
            text: "组件设置"
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
            color: Colors.text
        }
    }
    ClickRipple { id: widgetSettingsRipple; anchors.fill: parent; anchors.margins: 1; rippleColor: Colors.highlight }
    MouseArea {
        id: widgetSettingsArea; anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            widgetSettingsRipple.triggerRipple(mouse.x, mouse.y)
            BarLayoutService.activePanel = "layout";
            BarLayoutService.activeWidgetInstanceKey = root._targetWidgetKey;
            BarLayoutService.widgetSettingsX = root._targetWidgetCenterX;
            BarLayoutService.widgetSettingsPanelOpen = true;
            _dismissTimer.restart()
        }
    }
}

// --- "Copy widget" item ---
StaggerItem {
    id: s_widgetCopy
    visible: root._targetWidgetKey !== ""
    delay: SettingsService.data.animation.staggerLevel1BaseDelay
         + SettingsService.data.animation.staggerLevel1Step * 3
    exitDelay: 0
    width: parent.width
    height: visible ? Theme.barHeight - Theme.barPadding : 0

    HoverRevealHighlight {
        anchors.fill: parent; anchors.margins: 1
        radius: Theme.cornerRadius - 2
        hovered: widgetCopyArea.containsMouse
        highlightColor: Colors.highlight; highlightOpacity: 0.12
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: Theme.widgetPadding
        spacing: 8
        Text {
            text: "\uf0c5"
            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeIcon
            color: Colors.text; opacity: 0.7
        }
        Text {
            text: "复制组件"
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
            color: Colors.text
        }
    }
    ClickRipple { id: widgetCopyRipple; anchors.fill: parent; anchors.margins: 1; rippleColor: Colors.highlight }
    MouseArea {
        id: widgetCopyArea; anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            widgetCopyRipple.triggerRipple(mouse.x, mouse.y)
            let widgetId = root._targetWidgetKey.split("_").slice(0, -1).join("_");
            let payload = WidgetConfigService.exportPayload(widgetId, root._targetWidgetKey);
            _copyToClipboard(JSON.stringify(payload, null, 2));
            _dismissTimer.restart()
        }
    }
}

// --- "Delete widget" item ---
StaggerItem {
    id: s_widgetDelete
    visible: root._targetWidgetKey !== ""
    delay: SettingsService.data.animation.staggerLevel1BaseDelay
         + SettingsService.data.animation.staggerLevel1Step * 4
    exitDelay: 0
    width: parent.width
    height: visible ? Theme.barHeight - Theme.barPadding : 0

    HoverRevealHighlight {
        anchors.fill: parent; anchors.margins: 1
        radius: Theme.cornerRadius - 2
        hovered: widgetDeleteArea.containsMouse
        highlightColor: "#f7768e"; highlightOpacity: 0.15
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: Theme.widgetPadding
        spacing: 8
        Text {
            text: "\uf1f8"
            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeIcon
            color: "#f7768e"; opacity: 0.85
        }
        Text {
            text: "删除组件"
            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
            color: "#f7768e"
        }
    }
    ClickRipple { id: widgetDeleteRipple; anchors.fill: parent; anchors.margins: 1; rippleColor: "#f7768e" }
    MouseArea {
        id: widgetDeleteArea; anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            widgetDeleteRipple.triggerRipple(mouse.x, mouse.y)
            let key = root._targetWidgetKey;
            WidgetConfigService.removeConfig(key);
            BarLayoutService.removeWidget(key);
            _dismissTimer.restart()
        }
    }
}
```

### Step 5: Add `_copyToClipboard` helper function

After `showAt`, add:

```qml
function _copyToClipboard(text) {
    _clipboardWriter.stdin = text;
    _clipboardWriter.running = false;
    _clipboardWriter.running = true;
}
```

### Step 6: Add clipboard Process

Inside the root PopupWindow, alongside other Process/Timer children:

```qml
Process {
    id: _clipboardWriter
    property string stdin: ""
    stdinEnabled: true
    command: ["sh", "-c", "printf '%s' \"$0\" | xclip -sel clipboard", _clipboardWriter.stdin]
}
```

**Verify:** Hot-reload; right-click empty bar area → should still see only 2 items. Right-click on a widget (in next task) → will see widget section.

---

## Task 4 — Extend `BarWidgetWrapper` + `BarSection` delegate

**Files:**
- Modify `modules/bar/BarWidgetWrapper.qml`
- Modify `modules/bar/BarSection.qml`

### Step 1: Add `instanceKey` + helper props to `BarWidgetWrapper`

After `property string widgetId: ""`, add:

```qml
// Stable instance key in format "{widgetId}_{n}". Set by BarSection delegate.
property string instanceKey: ""
```

### Step 2: Add right-click handler to `BarWidgetWrapper`

After the `HoverHandler` block and before `Timer { id: widthAnimationRestoreTimer`, add:

```qml
// Right-click opens widget-specific context menu.
TapHandler {
    acceptedButtons: Qt.RightButton
    enabled: !BarLayoutService.isDragging
    onTapped: function(eventPoint) {
        let bc = wrapper.findBarContent();
        if (!bc) return;
        let centreInBar = wrapper.mapToItem(bc, wrapper._naturalWidth / 2, 0);
        let clickInWrapper = eventPoint.position;
        bc.openWidgetContextMenu(
            wrapper.instanceKey,
            wrapper.widgetId,
            clickInWrapper.x,
            centreInBar.x
        );
    }
}
```

### Step 3: Set `instanceKey` in `BarSection` widget delegate

In `BarSection.qml`, inside the `widgetDelegate` Component, extend `BarWidgetWrapper`:

```qml
BarWidgetWrapper {
    required property var modelData
    staggerIndex: modelData.index
    widgetId: modelData.widgetId
    instanceKey: BarLayoutService.instanceKeyAt(modelData.index)

    Loader {
        source: section.widgetRegistry[modelData.widgetId] || ""
        active: source !== ""
    }
}
```

### Step 4: Add `openWidgetContextMenu` to `BarContent`

In `BarContent.qml`, after the `hitTestSection` function:

```qml
// Called by BarWidgetWrapper on right-click. Forwards to the shared context menu
// with widget-specific arguments for the conditional widget section.
function openWidgetContextMenu(instanceKey, widgetId, clickX, widgetCenterX) {
    let label = widgetNames[widgetId] || widgetId;
    contextMenu.showAt(clickX, 0, instanceKey, widgetCenterX, label);
}

// Human-readable widget type names — mirrors WidgetPickerWindow.widgetNames.
// FIXME: promote to a shared singleton to avoid duplication.
readonly property var widgetNames: ({
    "clock":           "时钟",
    "workspaceWidget": "工作区"
})
```

**Verify:** Hot-reload; right-click a widget → context menu shows 5 items (布局模式, 设置, separator, 组件设置, 复制组件, 删除组件).

---

## Task 5 — Create `WidgetSettingsPanel`

**Files:**
- Create `modules/bar/WidgetSettingsPanel.qml`
- Create `modules/bar/widgetsettings/AppearanceSection.qml`
- Create `modules/bar/widgetsettings/WidgetActionsBar.qml`

### Step 1: Create `AppearanceSection.qml`

```qml
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Universal appearance overrides for a single widget instance.
// Reads from / writes to WidgetConfigService using the supplied instanceKey.
Item {
    id: root

    required property string instanceKey

    implicitHeight: col.implicitHeight

    readonly property var _app: WidgetConfigService.getAppearance(instanceKey)

    // Refresh binding when store changes
    Connections {
        target: WidgetConfigService
        function onStoreChanged() { root._refreshApp() }
    }

    function _refreshApp() {
        // Trigger re-evaluation of _app by reassigning to itself
        backgroundPicker.currentColor = root._app.backgroundColor || Colors.background;
        textPicker.currentColor       = root._app.textColor       || Colors.text;
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right }
        spacing: 4

        // Background colour row
        Row {
            width: parent.width
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "背景色"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: Colors.text
                width: 64
            }
            Rectangle {
                id: backgroundPicker
                property color currentColor: root._app.backgroundColor || Colors.background
                width: 32; height: 20; radius: 4
                color: currentColor
                border.color: Colors.border; border.width: 1
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    // FIXME: open a colour picker dialog when one is available
                    onClicked: {}
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root._app.backgroundColor || "（全局默认）")
                font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted; opacity: 0.7
            }
        }

        // Text colour row
        Row {
            width: parent.width
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "文字色"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: Colors.text
                width: 64
            }
            Rectangle {
                id: textPicker
                property color currentColor: root._app.textColor || Colors.text
                width: 32; height: 20; radius: 4
                color: currentColor
                border.color: Colors.border; border.width: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root._app.textColor || "（全局默认）")
                font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted; opacity: 0.7
            }
        }

        // Corner radius row — SliderSection pattern
        Row {
            width: parent.width; spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "圆角"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: Colors.text; width: 64
            }
            Slider {
                id: radiusSlider
                from: 0; to: 24; stepSize: 1
                value: root._app.cornerRadius !== undefined ? root._app.cornerRadius : Theme.cornerRadius
                width: parent.width - 64 - 8 - 40
                onMoved: WidgetConfigService.setAppearance(root.instanceKey, { cornerRadius: value })
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(radiusSlider.value)
                font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted; width: 32
            }
        }
    }
}
```

> Note: `Slider` requires `import QtQuick.Controls`. Add that import at the top.

### Step 2: Create `WidgetActionsBar.qml`

```qml
import QtQuick
import qs.config
import qs.services

// Bottom action row: Import | Export | Delete with process-backed file dialogs.
Item {
    id: root

    required property string instanceKey
    required property string widgetId

    implicitHeight: actionRow.implicitHeight + 4

    Row {
        id: actionRow
        anchors { left: parent.left; right: parent.right }
        spacing: 8

        // Import config
        Rectangle {
            width: (parent.width - 16) / 3
            height: 28; radius: Theme.cornerRadius - 2
            color: Colors.surface; border.color: Colors.border; border.width: 1
            Text {
                anchors.centerIn: parent; text: "导入"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: Colors.text
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: _importProc.running = true
            }
        }

        // Export config
        Rectangle {
            width: (parent.width - 16) / 3
            height: 28; radius: Theme.cornerRadius - 2
            color: Colors.surface; border.color: Colors.border; border.width: 1
            Text {
                anchors.centerIn: parent; text: "导出"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: Colors.text
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: _exportProc.running = true
            }
        }

        // Delete widget
        Rectangle {
            width: (parent.width - 16) / 3
            height: 28; radius: Theme.cornerRadius - 2
            color: Colors.surface; border.color: "#f7768e"; border.width: 1
            Text {
                anchors.centerIn: parent; text: "删除"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: "#f7768e"
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    WidgetConfigService.removeConfig(root.instanceKey);
                    BarLayoutService.removeWidget(root.instanceKey);
                    BarLayoutService.widgetSettingsPanelOpen = false;
                    BarLayoutService.activeWidgetInstanceKey = "";
                }
            }
        }
    }

    // Import — pick a JSON file and apply it
    Process {
        id: _importProc
        command: ["zenity", "--file-selection", "--title=导入组件配置", "--file-filter=*.json"]
        stdout: SplitParser {
            onRead: function(filePath) {
                _importReader.command = ["cat", filePath.trim()];
                _importReader.running = true;
            }
        }
    }
    Process {
        id: _importReader
        command: []
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    let obj = JSON.parse(data);
                    if (obj.appearance) WidgetConfigService.setAppearance(root.instanceKey, obj.appearance);
                } catch (e) { console.warn("WidgetActionsBar: import failed:", e); }
            }
        }
    }

    // Export — write current config to user-chosen file
    Process {
        id: _exportProc
        command: ["zenity", "--file-selection", "--save", "--confirm-overwrite",
                  "--title=导出组件配置", "--filename=widget-config.json"]
        stdout: SplitParser {
            onRead: function(filePath) {
                let payload = WidgetConfigService.exportPayload(root.widgetId, root.instanceKey);
                _exportWriter.command = ["sh", "-c",
                    "cat > '" + filePath.trim() + "'"];
                _exportWriter.running = true;
                _exportWriter.write(JSON.stringify(payload, null, 2) + "\n");
            }
        }
    }
    Process {
        id: _exportWriter
        stdinEnabled: true
        command: []
    }
}
```

### Step 3: Create `WidgetSettingsPanel.qml`

```qml
import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "widgetsettings"

// Floating bubble panel anchored below the bar, horizontally centred on the
// active widget. Shown when BarLayoutService.widgetSettingsPanelOpen = true.
//
// Must be instantiated inside BarContent with anchorTarget set to the BarContent Item.
PopupWindow {
    id: root

    required property Item anchorTarget

    visible: _state !== "closed"
    color: "transparent"
    focusable: true

    anchor.item: anchorTarget
    anchor.rect.y: anchorTarget.height
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.rect.x: Math.max(0, Math.min(
        BarLayoutService.widgetSettingsX - implicitWidth / 2,
        anchorTarget.width - implicitWidth))

    implicitWidth: 300
    implicitHeight: panelContent.implicitHeight + 24

    property string _state: "closed"

    readonly property bool _shouldBeOpen:
        BarLayoutService.widgetSettingsPanelOpen
        && BarLayoutService.activeWidgetInstanceKey !== ""

    on_ShouldBeOpenChanged: {
        if (_shouldBeOpen) {
            _state = "opening";
            panelContent.opacity = 0;
            panelContent.scale = 0.88;
            _enterAnim.restart();
        } else {
            if (_state !== "closed") {
                _state = "closing";
                _exitAnim.restart();
            }
        }
    }

    onFocusLost: {
        BarLayoutService.widgetSettingsPanelOpen = false;
        BarLayoutService.activeWidgetInstanceKey = "";
    }

    ParallelAnimation {
        id: _enterAnim
        NumberAnimation { target: panelContent; property: "opacity"; to: 1; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: panelContent; property: "scale";   to: 1; duration: 130; easing.type: Easing.OutBack; easing.overshoot: 0.4 }
        onFinished: root._state = "open"
    }

    SequentialAnimation {
        id: _exitAnim
        ParallelAnimation {
            NumberAnimation { target: panelContent; property: "opacity"; to: 0;    duration: 80; easing.type: Easing.InQuad }
            NumberAnimation { target: panelContent; property: "scale";   to: 0.88; duration: 80; easing.type: Easing.InQuad }
        }
        ScriptAction { script: root._state = "closed" }
    }

    Rectangle {
        id: panelContent
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1
        transformOrigin: Item.Top

        // Subtle inner highlight
        Rectangle {
            anchors.fill: parent; anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04); border.width: 1
        }

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            // Header row
            Row {
                Layout.fillWidth: true
                spacing: 8

                // Back button
                Rectangle {
                    width: 28; height: 28; radius: Theme.cornerRadius - 2
                    color: backArea.containsMouse ? Colors.highlight : "transparent"
                    opacity: backArea.containsMouse ? 0.15 : 1
                    Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf053"
                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text
                    }
                    MouseArea {
                        id: backArea; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            BarLayoutService.widgetSettingsPanelOpen = false;
                            BarLayoutService.activeWidgetInstanceKey = "";
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        let key = BarLayoutService.activeWidgetInstanceKey;
                        let widgetId = key.split("_").slice(0, -1).join("_");
                        let names = { clock: "时钟", workspaceWidget: "工作区" };
                        return (names[widgetId] || widgetId) + " 设置";
                    }
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    color: Colors.text
                    font.weight: Font.Medium
                }
            }

            // Divider
            Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border; opacity: 0.5 }

            // Appearance section
            Text {
                text: "外观"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted; opacity: 0.7
            }

            AppearanceSection {
                Layout.fillWidth: true
                instanceKey: BarLayoutService.activeWidgetInstanceKey
            }

            // Widget-specific config placeholder
            Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border; opacity: 0.5 }

            Text {
                text: "功能"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted; opacity: 0.7
            }

            Text {
                Layout.fillWidth: true
                text: "暂无可用设置"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                color: Colors.textMuted; opacity: 0.5
                horizontalAlignment: Text.AlignHCenter
            }

            // Spacer
            Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }

            // Action buttons
            WidgetActionsBar {
                Layout.fillWidth: true
                instanceKey: BarLayoutService.activeWidgetInstanceKey
                widgetId: {
                    let key = BarLayoutService.activeWidgetInstanceKey;
                    return key.split("_").slice(0, -1).join("_");
                }
            }
        }
    }
}
```

---

## Task 6 — Wire up in `BarContent`

**Files:** Modify `modules/bar/BarContent.qml`

### Step 1: Add import for WidgetSettingsPanel

`WidgetSettingsPanel.qml` is in the same `modules/bar/` directory and will be resolved automatically via the `qs.modules.bar` module — no explicit import needed.

### Step 2: Instantiate `WidgetSettingsPanel`

After the `BarContextMenu` instantiation:

```qml
WidgetSettingsPanel {
    anchorTarget: barContent
}
```

**Verify:** Hot-reload; right-click widget → click "组件设置" → panel should appear below bar at widget centre, layout mode outline appears on widget.

---

## Task 7 — Appearance Override Rendering in `BarWidgetWrapper`

**Files:** Modify `modules/bar/BarWidgetWrapper.qml`

### Step 1: Add import

Add `import qs.services` if not already present (verify at top of file).

### Step 2: Add computed appearance override property

After `property bool _isDragging: false`, add:

```qml
// Merged appearance: null values fall back to global theme tokens.
readonly property var _appearance: WidgetConfigService.getAppearance(wrapper.instanceKey)

// Refresh when the store changes (e.g. slider drag in settings panel)
Connections {
    target: WidgetConfigService
    function onStoreChanged() {
        // Force re-evaluation by reading the new value
        wrapper._appearanceChanged();
    }
}
signal _appearanceChanged
```

### Step 3: Apply background colour override

The existing `pulseBackground` Rectangle has `color: "transparent"`.  When an override is set and settings mode is *not* active, show the custom background.  Add a second background Rectangle below `pulseBackground`:

```qml
Rectangle {
    id: appearanceBg
    anchors.fill: parent
    radius: wrapper._appearance.cornerRadius !== undefined
            ? wrapper._appearance.cornerRadius : Theme.cornerRadius
    color: wrapper._appearance.backgroundColor || "transparent"
    z: -1
    opacity: wrapper._appearance.backgroundColor ? 1 : 0
    Behavior on color  { ColorAnimation  { duration: Theme.anim.highlightDuration } }
    Behavior on radius { NumberAnimation { duration: Theme.anim.highlightDuration } }
    Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
}
```

**Verify:** Open widget settings panel, change background colour (placeholder for now) → rectangle should update in real time.

---

## Task 8 — Commit

```bash
cd /home/Sighthesia/0_Files/Producing/Software/Quickshell/DymicShell
git add services/WidgetConfigService.qml \
        modules/bar/WidgetSettingsPanel.qml \
        modules/bar/widgetsettings/AppearanceSection.qml \
        modules/bar/widgetsettings/WidgetActionsBar.qml \
        services/BarLayoutService.qml \
        modules/bar/BarContextMenu.qml \
        modules/bar/BarWidgetWrapper.qml \
        modules/bar/BarSection.qml \
        modules/bar/BarContent.qml \
        docs/plans/2026-03-05-widget-settings-design.md \
        docs/plans/2026-03-05-widget-settings-plan.md
git commit -m "feat: widget right-click context menu + per-widget settings panel"
```

---

## Known Limitations / Follow-ups

- `AppearanceSection` colour pickers are placeholder rectangles; a full colour picker dialog (`zenity --color-selection` or a custom QML wheel) is a follow-up task.
- `WidgetConfigSection` functional config slot is empty; each widget type will eventually declare a `settingsComponent` property.
- Instance key stability: renaming / reordering widgets may shift keys. A stable UUID per entry in `layoutModel` should be added in a follow-up.
- Clipboard write via shell `xclip` requires `xclip` to be installed; fallback to `wl-copy` for Wayland-native access should be added.
