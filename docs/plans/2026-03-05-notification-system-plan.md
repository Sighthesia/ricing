# Notification System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete desktop notification system for DymicShell — ephemeral popup cards, persistent history panel, Bar bell widget, DND mode.

**Architecture:** `NotificationService` singleton holds all state (`activeList` + `historyList`); `NotificationPopupWindow` renders overlay cards; `NotificationBell` bar widget + `NotificationHistoryPanel` drop-down provide the Bar integration. All animations use `Theme.anim.*` tokens, all colors via `Colors.*`.

**Tech Stack:** QML / Quickshell, `Quickshell.Services.Notifications.NotificationServer`, `Quickshell.Io.FileView` for JSON persistence.

---

## Task 1: Extend Settings Defaults

**Files:**
- Modify: `config/settings-default.json`

**Step 1: Add `notifications` section**

In `config/settings-default.json`, add after the `"animation"` block:

```json
"notifications": {
    "position":         "top_right",
    "maxVisible":       5,
    "lowDuration":      3000,
    "normalDuration":   5000,
    "criticalDuration": 0,
    "persistHistory":   true,
    "maxHistory":       100
}
```

**Step 2: Commit**

```bash
git add config/settings-default.json
git commit -m "feat(notifications): add default settings"
```

---

## Task 2: Extend `BarLayoutService` with History Panel State

**Files:**
- Modify: `services/BarLayoutService.qml`

**Step 1: Add property**

In `BarLayoutService.qml`, after the `wallpaperPickerOpen` property, add:

```qml
// True while the notification history panel is visible.
property bool notificationHistoryOpen: false
```

**Step 2: Commit**

```bash
git add services/BarLayoutService.qml
git commit -m "feat(notifications): add notificationHistoryOpen to BarLayoutService"
```

---

## Task 3: Create `NotificationService`

**Files:**
- Create: `services/NotificationService.qml`

**Step 1: Write the file**

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import qs.services

// Notification service — single source of truth for all notification state.
//
// Consumers read from activeList (popup cards) and historyList (history panel).
// Never manipulate these models directly; use the public API methods below.
Singleton {
    id: root

    // --- Public state ---

    // Currently visible popup notifications (newest first).
    property ListModel activeList: ListModel {}

    // Persisted history, newest first.
    property ListModel historyList: ListModel {}

    // When true, new notifications are only appended to history — no popups shown.
    property bool doNotDisturb: false

    // Count of items added since markAllSeen() was last called.
    readonly property int unreadCount: _unreadCount

    // --- Public API ---

    // Dismiss a popup notification without removing it from history.
    function dismissActive(id) {
        var idx = _findActive(id);
        if (idx < 0) return;
        _stopTimer(id);
        activeList.remove(idx);
    }

    // Invoke a notification action then dismiss the popup.
    function invokeAction(id, identifier) {
        var entry = _activeNotifications[id];
        if (entry) {
            entry.notification.invokeAction(identifier);
        }
        dismissActive(id);
    }

    // Remove a single entry from the persisted history.
    function removeFromHistory(id) {
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).id === id) {
                historyList.remove(i);
                _scheduleSave();
                return;
            }
        }
    }

    // Clear the entire history.
    function clearHistory() {
        historyList.clear();
        _scheduleSave();
    }

    // Mark all current items as read — resets unreadCount to 0.
    function markAllSeen() {
        _lastSeenTimestamp = Date.now();
        _updateUnreadCount();
        _scheduleSave();
    }

    // --- Private state ---

    property int _unreadCount: 0
    property real _lastSeenTimestamp: 0

    // id → { notification: NotificationObject, timer: Timer }
    property var _activeNotifications: ({})

    readonly property string _cacheDir:
        (Quickshell.env("XDG_CACHE_HOME") !== ""
            ? Quickshell.env("XDG_CACHE_HOME")
            : Quickshell.env("HOME") + "/.cache")
        + "/dymicshell/"

    readonly property string _historyFile: _cacheDir + "notifications.json"

    // --- Notification server ---

    NotificationServer {
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        onNotification: (n) => root._handleNotification(n)
    }

    // --- History persistence ---

    FileView {
        id: historyFileView
        path: root._historyFile
        onLoaded: root._loadHistory(text)
        onLoadFailed: root._scheduleSave() // First run: write empty file
    }

    Timer {
        id: saveTimer
        interval: 300
        repeat: false
        onTriggered: root._writeToDisk()
    }

    // --- Timer component for auto-dismiss ---

    Component {
        id: dismissTimerComponent
        Timer {
            property string notifId: ""
            repeat: false
            onTriggered: root.dismissActive(notifId)
        }
    }

    // --- Internal logic ---

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", _cacheDir])
    }

    function _handleNotification(n) {
        var data = _buildData(n);

        // Always append to history (unless transient)
        if (!n.transient) {
            _prependHistory(data);
        }

        if (root.doNotDisturb) return;

        // Replace existing popup from same app+summary if present
        for (var i = 0; i < activeList.count; i++) {
            var existing = activeList.get(i);
            if (existing.appName === data.appName && existing.summary === data.summary) {
                _stopTimer(existing.id);
                activeList.set(i, data);
                _startTimer(data);
                return;
            }
        }

        // Enforce maxVisible — remove oldest (bottom)
        var maxV = SettingsService.data.notifications.maxVisible || 5;
        while (activeList.count >= maxV) {
            var last = activeList.get(activeList.count - 1);
            _stopTimer(last.id);
            activeList.remove(activeList.count - 1);
        }

        activeList.insert(0, data);
        _startTimer(data);
        _unreadCount++;
    }

    function _buildData(n) {
        var actions = [];
        if (n.actions) {
            for (var i = 0; i < n.actions.length; i++) {
                actions.push({ identifier: n.actions[i].identifier, text: n.actions[i].text });
            }
        }
        return {
            id:        String(n.id),
            appName:   n.appName  || "",
            summary:   n.summary  || "",
            body:      n.body     || "",
            appIcon:   n.appIcon  || "",
            urgency:   (n.urgency >= 0 && n.urgency <= 2) ? n.urgency : 1,
            timestamp: Date.now(),
            actionsJson: JSON.stringify(actions)
        };
    }

    function _startTimer(data) {
        var d = SettingsService.data.notifications;
        var durations = [
            d.lowDuration     !== undefined ? d.lowDuration     : 3000,
            d.normalDuration  !== undefined ? d.normalDuration  : 5000,
            d.criticalDuration !== undefined ? d.criticalDuration : 0
        ];
        var ms = durations[data.urgency];
        if (ms <= 0) return; // 0 = never auto-dismiss

        var t = dismissTimerComponent.createObject(root, { notifId: data.id, interval: ms });
        t.start();
        _activeNotifications[data.id] = { timer: t };
    }

    function _stopTimer(id) {
        var entry = _activeNotifications[id];
        if (entry && entry.timer) {
            entry.timer.stop();
            entry.timer.destroy();
        }
        delete _activeNotifications[id];
    }

    function _findActive(id) {
        for (var i = 0; i < activeList.count; i++) {
            if (activeList.get(i).id === id) return i;
        }
        return -1;
    }

    function _prependHistory(data) {
        historyList.insert(0, data);
        var maxH = SettingsService.data.notifications.maxHistory || 100;
        while (historyList.count > maxH) {
            historyList.remove(historyList.count - 1);
        }
        _unreadCount++;
        _scheduleSave();
    }

    function _updateUnreadCount() {
        var count = 0;
        for (var i = 0; i < historyList.count; i++) {
            if (historyList.get(i).timestamp > _lastSeenTimestamp) count++;
        }
        _unreadCount = count;
    }

    function _scheduleSave() {
        if (SettingsService.data.notifications.persistHistory !== false) {
            saveTimer.restart();
        }
    }

    function _writeToDisk() {
        var items = [];
        for (var i = 0; i < historyList.count; i++) {
            items.push(historyList.get(i));
        }
        var payload = JSON.stringify({ lastSeenTimestamp: _lastSeenTimestamp, items: items }, null, 2);
        historyFileView.setText(payload);
    }

    function _loadHistory(text) {
        try {
            var parsed = JSON.parse(text);
            if (parsed.lastSeenTimestamp) _lastSeenTimestamp = parsed.lastSeenTimestamp;
            var items = parsed.items || [];
            historyList.clear();
            for (var i = 0; i < items.length; i++) {
                historyList.append(items[i]);
            }
            _updateUnreadCount();
        } catch (e) {
            // Corrupt or empty file — start fresh
        }
    }
}
```

**Step 2: Verify QML import path**

The file lives in `services/` which is already registered as `qs.services`. No extra registration needed — Quickshell auto-discovers `pragma Singleton` files.

**Step 3: Commit**

```bash
git add services/NotificationService.qml
git commit -m "feat(notifications): add NotificationService singleton"
```

---

## Task 4: Create `NotificationCard.qml`

**Files:**
- Create: `modules/notifications/NotificationCard.qml`

This is a single visual popup card. It handles entry/exit animations, swipe-to-dismiss, and action buttons.

**Step 1: Create directory and write file**

Run: `mkdir -p modules/notifications`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// Single notification popup card.
//
// Parent must set `notifId`, `appName`, `summary`, `body`, `appIcon`,
// `urgency`, and `actionsJson`. Call `triggerEnter()` after creation
// and `triggerExit()` to dismiss with animation.
Item {
    id: card

    // --- Required properties ---
    required property string notifId
    required property string appName
    required property string summary
    required property string body
    required property string appIcon
    required property int    urgency
    required property string actionsJson

    // Emitted when exit animation completes — parent should call NotificationService.dismissActive()
    signal dismissRequested(string id)

    // Pause/resume the auto-dismiss timer on hover
    signal hoverEntered(string id)
    signal hoverExited(string id)

    implicitWidth: 360
    implicitHeight: _bg.implicitHeight

    // --- Animation state ---
    property real _opacity: 0.0
    property real _offsetY: -20

    opacity: _opacity
    transform: Translate { y: card._offsetY }

    function triggerEnter() {
        _opacity = 1.0;
        _offsetY = 0;
    }

    function triggerExit() {
        _opacity = 0.0;
        _offsetY = -10;
    }

    Behavior on _opacity {
        NumberAnimation {
            duration: Theme.anim.exitDuration
            easing.type: Theme.anim.exitType
        }
    }

    Behavior on _offsetY {
        NumberAnimation {
            duration: Theme.anim.exitDuration
            easing.type: Easing.InExpo
        }
    }

    // Watch for exit animation completion to emit dismissRequested
    onOpacityChanged: {
        if (opacity < 0.01 && _offsetY < -5) {
            card.dismissRequested(card.notifId);
        }
    }

    // --- Swipe state ---
    property real _swipeX: 0
    property bool _swiping: false

    transform: [
        Translate { y: card._offsetY },
        Translate { x: card._swipeX }
    ]

    DragHandler {
        id: dragH
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (!active) {
                var threshold = card.implicitWidth * 0.35;
                if (Math.abs(card._swipeX) >= threshold) {
                    card._swipeX = card._swipeX > 0 ? card.implicitWidth + 20 : -(card.implicitWidth + 20);
                    card.triggerExit();
                } else {
                    card._swipeX = 0;
                }
                card._swiping = false;
            } else {
                card._swiping = true;
            }
        }
        onTranslationChanged: {
            if (active) card._swipeX = translation.x;
        }
    }

    Behavior on _swipeX {
        enabled: !card._swiping
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }

    // --- Visual card ---
    Rectangle {
        id: _bg
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: _content.implicitHeight + 16
        radius: Theme.cornerRadius
        color: Colors.surface
        border.color: {
            if (urgency === 2) return Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.8)
            return Colors.border
        }
        border.width: 1

        // Hover detection
        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) card.hoverEntered(card.notifId)
                else card.hoverExited(card.notifId)
            }
        }

        // Right-click to dismiss immediately
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: card.triggerExit()
        }

        ColumnLayout {
            id: _content
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 12
            spacing: 4

            // Header: app icon + app name + close button
            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                // App icon — falls back gracefully to colored initial letter
                Rectangle {
                    width: 18; height: 18
                    radius: 4
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)
                    visible: card.appIcon === ""

                    Text {
                        anchors.centerIn: parent
                        text: card.appName.length > 0 ? card.appName[0].toUpperCase() : "?"
                        font.pixelSize: 11
                        font.bold: true
                        color: Colors.highlight
                    }
                }

                IconImage {
                    width: 18; height: 18
                    visible: card.appIcon !== ""
                    source: card.appIcon.startsWith("/") ? ("file://" + card.appIcon) : ("image://icon/" + card.appIcon)
                }

                Text {
                    text: card.appName
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Close button
                TapHandler { onTapped: card.triggerExit() }
                Text {
                    text: "✕"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }
            }

            // Summary
            Text {
                text: card.summary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                color: Colors.text
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // Body
            Text {
                text: card.body
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: card.body !== ""
            }

            // Action buttons
            RowLayout {
                spacing: 6
                visible: _actions.length > 0
                Layout.topMargin: 2

                property var _actions: {
                    try { return JSON.parse(card.actionsJson) } catch(e) { return [] }
                }

                Repeater {
                    model: parent._actions
                    delegate: Rectangle {
                        required property var modelData
                        implicitHeight: _lbl.implicitHeight + 8
                        implicitWidth: _lbl.implicitWidth + 16
                        radius: Theme.cornerRadius / 2
                        color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, _tap.pressed ? 0.25 : 0.1)

                        Text {
                            id: _lbl
                            anchors.centerIn: parent
                            text: modelData.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.highlight
                        }

                        TapHandler {
                            id: _tap
                            onTapped: NotificationService.invokeAction(card.notifId, modelData.identifier)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        // Defer entry animation one frame to allow layout to settle
        Qt.callLater(triggerEnter);
    }
}
```

**Step 2: Commit**

```bash
git add modules/notifications/NotificationCard.qml
git commit -m "feat(notifications): add NotificationCard component"
```

---

## Task 5: Create `NotificationPopupWindow.qml`

**Files:**
- Create: `modules/notifications/NotificationPopupWindow.qml`

**Step 1: Write the file**

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Overlay window that renders ephemeral notification popup cards.
//
// Position is driven by SettingsService.data.notifications.position:
//   "top_right" | "top_left" | "bottom_right" | "bottom_left"
// Bar edge offset is automatically applied based on bar position setting.
PanelWindow {
    id: root

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Compute anchoring from position setting
    readonly property string _pos: SettingsService.data.notifications.position || "top_right"
    readonly property bool _isTop: _pos.startsWith("top")
    readonly property bool _isRight: _pos.endsWith("right")

    anchors.top:    _isTop
    anchors.bottom: !_isTop
    anchors.right:  _isRight
    anchors.left:   !_isRight

    // Offset card column away from the bar edge and screen edge
    readonly property int _edgeMargin: 12
    readonly property int _barOffset:  Theme.barHeight + _edgeMargin

    margins.top:    _isTop    ? _barOffset   : _edgeMargin
    margins.bottom: !_isTop   ? _barOffset   : _edgeMargin
    margins.right:  _isRight  ? _edgeMargin  : 0
    margins.left:   !_isRight ? _edgeMargin  : 0

    implicitWidth: 376   // card width (360) + 2×8 padding
    implicitHeight: _column.implicitHeight + 8

    // Click-through when no cards are showing
    visible: NotificationService.activeList.count > 0

    Column {
        id: _column
        anchors {
            left:  root._isRight  ? undefined : parent.left
            right: root._isRight  ? parent.right : undefined
            top:   root._isTop    ? parent.top   : undefined
            bottom: !root._isTop  ? parent.bottom : undefined
        }
        spacing: 8
        padding: 8

        Repeater {
            id: _repeater
            model: NotificationService.activeList

            delegate: NotificationCard {
                id: _card

                notifId:     model.id
                appName:     model.appName
                summary:     model.summary
                body:        model.body
                appIcon:     model.appIcon
                urgency:     model.urgency
                actionsJson: model.actionsJson

                onDismissRequested: (id) => NotificationService.dismissActive(id)

                onHoverEntered: (id) => {
                    _pauseTimers[id] = true;
                }
                onHoverExited: (id) => {
                    delete _pauseTimers[id];
                }
            }
        }
    }

    // FIXME: timer pause on hover is tracked here but NotificationService needs
    // to expose pauseTimer(id)/resumeTimer(id) API in a follow-up.
    property var _pauseTimers: ({})
}
```

**Step 2: Commit**

```bash
git add modules/notifications/NotificationPopupWindow.qml
git commit -m "feat(notifications): add NotificationPopupWindow"
```

---

## Task 6: Register `NotificationPopupWindow` in `shell.qml`

**Files:**
- Modify: `shell.qml`
- Modify: (verify `modules/notifications/` module path is auto-discovered by Quickshell)

**Step 1: Add import and instance**

Edit `shell.qml`:

```qml
//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications

ShellRoot {
    BackgroundWindow {}
    BarWindow {}
    SettingsPanelWindow {}
    ContextMenuBackdrop {}
    WidgetPickerWindow {}
    WallpaperPickerWindow {}
    NotificationPopupWindow {}
}
```

> **Note:** Quickshell auto-registers QML type dirs. The import path `qs.modules.notifications` works if directory is `modules/notifications/`. Verify by running the shell; if the import fails, use a relative import path instead: `import "./modules/notifications"`.

**Step 2: Commit**

```bash
git add shell.qml
git commit -m "feat(notifications): register NotificationPopupWindow in shell"
```

---

## Task 7: Create `NotificationHistoryPanel.qml`

**Files:**
- Create: `modules/bar/NotificationHistoryPanel.qml`

**Step 1: Write the file**

```qml
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Drop-down panel showing notification history, anchored below the bar at the right edge.
// Opened/closed by BarLayoutService.notificationHistoryOpen.
AnimatedPanelBase {
    id: root

    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth: 400
    implicitHeight: 480
    focusable: false

    active: BarLayoutService.notificationHistoryOpen

    // Mark all notifications as seen when panel opens
    onPanelOpening: NotificationService.markAllSeen()

    // Panel background
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "通知"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Colors.text
                    Layout.fillWidth: true
                }

                // Clear all button
                Rectangle {
                    implicitHeight: 24
                    implicitWidth: _clearLbl.implicitWidth + 16
                    radius: Theme.cornerRadius / 2
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b,
                                   _clearTap.pressed ? 0.2 : 0.08)
                    visible: NotificationService.historyList.count > 0

                    Text {
                        id: _clearLbl
                        anchors.centerIn: parent
                        text: "清空"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.highlight
                    }

                    TapHandler {
                        id: _clearTap
                        onTapped: NotificationService.clearHistory()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.border
                opacity: 0.5
            }

            // History list
            ListView {
                id: _list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: NotificationService.historyList

                delegate: _HistoryItem {}

                // Empty state
                Text {
                    anchors.centerIn: parent
                    visible: NotificationService.historyList.count === 0
                    text: "暂无通知"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    color: Colors.textMuted
                }
            }
        }
    }

    // Compact history item component
    component _HistoryItem: Item {
        width: ListView.view.width
        implicitHeight: _row.implicitHeight + 16

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius / 2
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
            border.color: Colors.border
            border.width: 1

            RowLayout {
                id: _row
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.margins: 10
                spacing: 8

                // App initial letter badge
                Rectangle {
                    width: 28; height: 28
                    radius: 6
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: appName.length > 0 ? appName[0].toUpperCase() : "?"
                        font.pixelSize: 12
                        font.bold: true
                        color: Colors.highlight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: appName
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: {
                                var diff = Date.now() - timestamp;
                                if (diff < 60000) return "刚刚";
                                if (diff < 3600000) return Math.floor(diff/60000) + "分钟前";
                                if (diff < 86400000) return Math.floor(diff/3600000) + "小时前";
                                return Math.floor(diff/86400000) + "天前";
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                        }
                    }

                    Text {
                        text: summary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Colors.text
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: body
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        visible: body !== ""
                    }
                }

                // Delete button
                TapHandler {
                    onTapped: NotificationService.removeFromHistory(id)
                }
                Text {
                    text: "✕"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add modules/bar/NotificationHistoryPanel.qml
git commit -m "feat(notifications): add NotificationHistoryPanel"
```

---

## Task 8: Create `NotificationBell.qml` Bar Widget

**Files:**
- Create: `modules/bar/widgets/NotificationBell.qml`

**Step 1: Write the file**

```qml
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Bar widget — bell icon with unread badge, toggles history panel on click.
// Place inside BarWidgetWrapper in BarSection.
Rectangle {
    id: bell

    color: Colors.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: _row.width + Theme.widgetPadding * 2

    // Hover highlight
    HoverRevealHighlight { anchors.fill: parent; hovered: _area.containsMouse }

    // Click ripple
    ClickRipple { id: _ripple; anchors.fill: parent }

    RowLayout {
        id: _row
        anchors.centerIn: parent
        spacing: 0

        // Bell icon — switches to muted icon when DND is active
        Text {
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeIcon
            color: NotificationService.doNotDisturb ? Colors.textMuted : Colors.text
            // FIXME: replace with proper Nerd Font / Material Symbols glyph
            text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"

            // Unread badge
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -2
                anchors.rightMargin: -2
                width: 8; height: 8
                radius: 4
                color: Colors.highlight
                visible: NotificationService.unreadCount > 0
            }
        }
    }

    // Hover / click area
    MouseArea {
        id: _area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            _ripple.triggerRipple(mouse.x, mouse.y);
            if (mouse.button === Qt.RightButton) {
                _ctxMenu.open();
                return;
            }
            BarLayoutService.notificationHistoryOpen = !BarLayoutService.notificationHistoryOpen;
        }
    }

    // Right-click context menu
    _BellContextMenu { id: _ctxMenu }

    // Inline context menu component
    component _BellContextMenu: QtObject {
        // FIXME: implement as a proper PopupWindow following BarContextMenu pattern
        function open() {
            NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
        }
    }
}
```

> **Note:** The right-click context menu uses a minimal inline stub that only toggles DND. A full `PopupWindow`-based context menu can be added as a follow-up task to match the `BarContextMenu` pattern.

**Step 2: Register widget in `BarContent.qml`**

In `modules/bar/BarContent.qml`, add `"notificationBell"` to `widgetRegistry`:

```qml
readonly property var widgetRegistry: ({
    "clock":              "widgets/Clock.qml",
    "workspaceWidget":    "widgets/WorkspaceWidget.qml",
    "notificationBell":   "widgets/NotificationBell.qml"
})
```

Also add to `widgetNames`:

```qml
readonly property var widgetNames: ({
    "clock":              "时钟",
    "workspaceWidget":    "工作区",
    "notificationBell":   "通知"
})
```

**Step 3: Register in `WidgetPickerWindow.qml`**

Find the `widgetNames` or widget list in `WidgetPickerWindow.qml` and add `"notificationBell": "通知"`.

**Step 4: Instantiate `NotificationHistoryPanel` in `BarWindow.qml`**

In `modules/bar/BarWindow.qml`, after `BarContent`, add:

```qml
NotificationHistoryPanel {}
```

**Step 5: Commit**

```bash
git add modules/bar/widgets/NotificationBell.qml modules/bar/BarContent.qml
git add modules/bar/BarWindow.qml
git commit -m "feat(notifications): add NotificationBell widget and wire history panel"
```

---


**Goal:** Verify the notification system works end to end.

**Step 1: Start the shell**

```bash
quickshell -p /path/to/DymicShell
```

**Step 2: Send a test notification**

```bash
notify-send "Test App" "This is the notification body" --urgency=normal
notify-send "Urgent" "Critical alert" --urgency=critical
```

**Expected:** Popup cards appear at configured position. Critical card does NOT auto-dismiss.

**Step 3: Test history panel**

Click the bell icon in the bar. Expect the history panel to drop down showing previous notifications. Unread badge count should reset to 0.

**Step 4: Test DND**

Right-click the bell icon. Send another `notify-send`. Expected: no popup appears, but notification IS added to history.

**Step 5: Test swipe dismiss**

Click and drag a popup card horizontally past ~35% of its width. Expected: card flies off screen and is removed.

**Step 6: Commit any fixes**

```bash
git add -p
git commit -m "fix(notifications): <describe fix>"
```

---

## Task 10: Settings UI Integration (Optional Follow-up)

**Files:**
- Modify: `modules/bar/settings/AppearancePage.qml` or add a dedicated `NotificationsPage.qml`

Add settings rows for:
- `notifications.position` — `SliderSection` or dropdown
- `notifications.lowDuration` / `normalDuration` / `criticalDuration` — `SliderSection`
- `notifications.maxVisible` — `SliderSection`
- `notifications.persistHistory` — `ToggleSection`

This can be deferred until the core functionality is verified working.

---

## Execution Handoff

Plan saved to `docs/plans/2026-03-05-notification-system-plan.md`.

**Two execution options:**

**1. Subagent-Driven (this session)** — dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — open a new session with `executing-plans`, batch execution with checkpoints

Which approach?
