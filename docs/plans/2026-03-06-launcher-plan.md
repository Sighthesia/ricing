# Launcher Core Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a native QML application launcher panel triggered via Quickshell IPC, displaying `.desktop` applications with fuzzy search and keyboard navigation.

**Architecture:** `LauncherService` (Singleton + IpcHandler) controls open/close state. `LauncherPanel` (AnimatedPanelBase) renders the panel below the bar center. `LauncherCore` owns the search field + result list + ApplicationsProvider.

**Tech Stack:** Quickshell QML, `DesktopEntries.applications`, `Quickshell.Io.IpcHandler`, `AnimatedPanelBase`

---

## Context for Implementer

- **Import paths**: `qs.services` resolves to `services/`, `qs.config` to `config/`, `qs.modules.launcher` to `modules/launcher/`.
- **Singleton pattern**: `pragma Singleton` + `Singleton { id: root }` — copy from `services/NotificationService.qml`.
- **AnimatedPanelBase**: use `active:` not `visible:`, children auto-route via `default property alias`. See `modules/bar/NotificationHistoryPanel.qml`.
- **IPC**: `IpcHandler { target: "launcher"; function toggle(): void {...} }` — called via `qs ipc call launcher.toggle`.
- **QML file order**: imports → root id → required property → property → readonly property → `property _xxx` → signal → children → functions → `Component.onCompleted` → `Connections`.

---

### Task 1: Create LauncherService singleton

**Files:**
- Create: `services/LauncherService.qml`

**Step 1: Write the file**

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Central state for the launcher panel.
// Opened/closed by external IPC or internal code — no bar widget.
Singleton {
    id: root

    property bool isOpen: false
    // Text to prefill in the search box when opening via IPC.
    property string prefillText: ""

    function toggle(): void {
        if (root.isOpen) {
            root.prefillText = "";
            root.isOpen = false;
        } else {
            root.prefillText = "";
            root.isOpen = true;
        }
    }

    function openClipboard(): void {
        root.prefillText = ">clip ";
        root.isOpen = true;
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle(); }
        function openClipboard(): void { root.openClipboard(); }
    }
}
```

**Step 2: Verify qs picks it up (no startup crash)**

```bash
cd /path/to/worktree
qs --path . 2>&1 | head -20
# Expected: no errors mentioning LauncherService
```

**Step 3: Commit**

```bash
git add services/LauncherService.qml
git commit -m "feat(launcher): add LauncherService singleton with IPC handler"
```

---

### Task 2: Create ApplicationsProvider

**Files:**
- Create: `modules/launcher/providers/ApplicationsProvider.qml`

**Step 1: Write the file**

```qml
import Quickshell
import Quickshell.Services.Applications
import QtQuick

// Provides application launch results from XDG desktop entries.
// Uses DesktopEntries.applications — no filesystem scanning needed.
Item {
    id: root

    // Provider interface
    property bool handleSearch: true

    function onOpened(): void {
        // DesktopEntries is always up-to-date; nothing to preload.
    }

    // Returns [{name, description, icon, onActivate}] filtered by text.
    function getResults(text: string): var {
        let results = [];
        let query = text.trim().toLowerCase();
        let apps = DesktopEntries.applications.values;

        for (let i = 0; i < apps.length; i++) {
            let app = apps[i];
            if (app.noDisplay || app.hidden) continue;

            let nameMatch  = app.name.toLowerCase().includes(query);
            let descMatch  = app.comment ? app.comment.toLowerCase().includes(query) : false;
            if (query !== "" && !nameMatch && !descMatch) continue;

            results.push({
                name:        app.name,
                description: app.comment || app.genericName || "",
                icon:        app.icon    || "application-x-executable",
                onActivate:  (function(a) {
                    return function() { a.launch(); };
                })(app)
            });
        }

        // Sort: exact name-start matches first, then alphabetical.
        results.sort(function(a, b) {
            let aStart = a.name.toLowerCase().startsWith(query) ? 0 : 1;
            let bStart = b.name.toLowerCase().startsWith(query) ? 0 : 1;
            if (aStart !== bStart) return aStart - bStart;
            return a.name.localeCompare(b.name);
        });

        return results.slice(0, 50);
    }
}
```

**Step 2: Check `DesktopEntries` import**

Run: `qs --version` to confirm Quickshell ≥ 0.2 (DesktopEntries.applications available).

**Step 3: Commit**

```bash
git add modules/launcher/providers/ApplicationsProvider.qml
git commit -m "feat(launcher): add ApplicationsProvider using DesktopEntries"
```

---

### Task 3: Create LauncherCore

**Files:**
- Create: `modules/launcher/LauncherCore.qml`

**Step 1: Write the file**

```qml
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services

// Central search + results component embedded inside LauncherPanel.
// Owns all providers and routes queries to the active one.
Item {
    id: root

    // Called by LauncherPanel after panel becomes active
    function openPanel(): void {
        _results.clear();
        searchField.text = LauncherService.prefillText;
        searchField.forceActiveFocus();
        _refreshResults();
        for (let i = 0; i < _providers.length; i++) {
            _providers[i].onOpened();
        }
    }

    // Called by LauncherPanel when closing
    function closePanel(): void {
        searchField.text = "";
        _results.clear();
    }

    // --- Private state ---
    property var _providers: [appProvider]
    property string _query: ""

    ListModel { id: _results }

    function _activeProvider(): var {
        let text = searchField.text;
        if (text.startsWith(">clip ") || text === ">clip") return null; // clipboard stub for now
        return appProvider;
    }

    function _refreshResults(): void {
        _results.clear();
        let provider = _activeProvider();
        if (!provider) return;

        let q = searchField.text;
        // Strip command prefix if present
        let cleanQ = q;
        let items = provider.getResults(cleanQ);
        for (let i = 0; i < items.length; i++) {
            _results.append(items[i]);
        }
        _selectedIndex = items.length > 0 ? 0 : -1;
    }

    property int _selectedIndex: -1

    // --- UI ---
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Search bar row
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Mode badge
                Rectangle {
                    implicitWidth: _modeBadgeText.implicitWidth + 16
                    height: 24
                    radius: Theme.cornerRadius / 2
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)

                    Text {
                        id: _modeBadgeText
                        anchors.centerIn: parent
                        text: searchField.text.startsWith(">clip") ? "剪切板" : "应用"
                        color: Colors.highlight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "搜索应用… (>clip 切换剪切板)"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    color: Colors.text
                    background: null
                    selectionColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.3)

                    onTextChanged: Qt.callLater(root._refreshResults)

                    Keys.onUpPressed: {
                        if (root._selectedIndex > 0) root._selectedIndex--;
                        resultList.positionViewAtIndex(root._selectedIndex, ListView.Contain);
                    }
                    Keys.onDownPressed: {
                        if (root._selectedIndex < _results.count - 1) root._selectedIndex++;
                        resultList.positionViewAtIndex(root._selectedIndex, ListView.Contain);
                    }
                    Keys.onReturnPressed: root._activateCurrent()
                    Keys.onEscapePressed: LauncherService.isOpen = false
                }
            }
        }

        // Divider
        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border }

        // Results list
        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: _results
            clip: true

            delegate: Rectangle {
                width: resultList.width
                height: 52
                color: root._selectedIndex === index
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Image {
                        source: "image://icon/" + (model.icon || "application-x-executable")
                        width: 24; height: 24
                        sourceSize: Qt.size(24, 24)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.name
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: model.description
                            color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: model.description !== ""
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root._selectedIndex = index
                    onClicked: root._activateCurrent()
                }
            }
        }
    }

    function _activateCurrent(): void {
        if (root._selectedIndex < 0 || root._selectedIndex >= _results.count) return;
        let item = _results.get(root._selectedIndex);
        LauncherService.isOpen = false;
        if (item.onActivate) item.onActivate();
    }

    // Provider instances (children of LauncherCore)
    ApplicationsProvider { id: appProvider }
}
```

**Step 2: Commit**

```bash
git add modules/launcher/LauncherCore.qml
git commit -m "feat(launcher): add LauncherCore with search field and result list"
```

---

### Task 4: Create LauncherPanel (AnimatedPanelBase window)

**Files:**
- Create: `modules/launcher/LauncherPanel.qml`

**Step 1: Write the file**

```qml
import Quickshell
import QtQuick
import qs.config
import qs.services

// Launcher overlay panel — centred below the bar, opens/closes via LauncherService.isOpen.
// IPC: `qs ipc call launcher.toggle` / `qs ipc call launcher.openClipboard`
AnimatedPanelBase {
    id: panelWindow

    anchors { top: true; horizontalCenter: true }
    margins { top: Theme.barHeight }

    implicitWidth: 640
    implicitHeight: 480
    focusable: true

    active: LauncherService.isOpen

    onPanelOpening: _core.openPanel()
    onPanelClosing: _core.closePanel()

    // Panel background card
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // Inner highlight border
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }
    }

    LauncherCore {
        id: _core
        anchors {
            fill: parent
            topMargin: 4
            leftMargin: 4
            rightMargin: 4
            bottomMargin: 4
        }
    }
}
```

**Step 2: Commit**

```bash
git add modules/launcher/LauncherPanel.qml
git commit -m "feat(launcher): add LauncherPanel AnimatedPanelBase window"
```

---

### Task 5: Register in shell.qml

**Files:**
- Modify: `shell.qml`

**Step 1: Add import and instantiation**

In `shell.qml`, add `import qs.modules.launcher` and `LauncherPanel {}`:

```qml
//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications
import qs.modules.launcher

ShellRoot {
    BackgroundWindow {}
    BarWindow {}
    SettingsPanelWindow {}
    ContextMenuBackdrop {}
    WidgetPickerWindow {}
    WallpaperPickerWindow {}
    NotificationPopupWindow {}
    NotificationHistoryPanel {}
    LauncherPanel {}
}
```

**Step 2: Verify shell loads**

```bash
qs --path . 2>&1 | grep -i "error\|warn" | head -20
# Expected: no launcher-related errors
```

**Step 3: Test IPC trigger**

```bash
# While qs is running:
qs ipc call launcher.toggle
# Expected: launcher panel slides down from bar center
qs ipc call launcher.toggle
# Expected: panel closes
```

**Step 4: Commit**

```bash
git add shell.qml
git commit -m "feat(launcher): register LauncherPanel in shell.qml"
```

---


**Step 1: Launch shell and verify**

```bash
qs --path .
# In separate terminal:
qs ipc call launcher.toggle
# Type "fire" — should show Firefox etc.
# Press Down arrow, Enter — should launch app
# Press Escape — panel closes
```

**Step 2: Commit final**

```bash
git add -A
git commit -m "feat(launcher): launcher core complete — apps search + IPC trigger"
```

---

## Notes

- `DesktopEntries` is from `import Quickshell.Services.Applications` (Quickshell ≥ 0.2).
- `image://icon/<name>` is Quickshell's built-in XDG icon provider — no extra setup needed.
- `LauncherService.prefillText` is read once in `openPanel()`; reset on close.
- After `feat/clipboard-service` is merged into this branch, add `ClipboardProvider` to `_providers` in LauncherCore and handle the `>clip ` prefix routing.
