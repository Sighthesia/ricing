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

    signal notificationReceived(var data)

    // --- Public state ---

    // Currently visible popup notifications (newest first).
    property ListModel activeList: ListModel {}

    // Persisted history, newest first.
    property ListModel historyList: ListModel {}

    // When true, new notifications are only appended to history — no popups shown.
    property bool doNotDisturb: false

    // Runtime gate for popup presentation. Shell settings decide whether popup windows are allowed.
    property bool popupsEnabled: true
    readonly property bool popupPresentationEnabled:
        popupsEnabled && !SettingsService.data.superIsland.showNotifications

    // Count of items added since markAllSeen() was last called.
    readonly property int unreadCount: _unreadCount
    readonly property bool notificationsAvailable: _notificationsAvailable
    readonly property string notificationOwner: _notificationOwner
    readonly property string notificationDiagnosticMessage: _notificationDiagnosticMessage

    // --- Private state ---

    property int _unreadCount: 0
    property real _lastSeenTimestamp: 0
    property bool _notificationsAvailable: true
    property string _notificationOwner: ""
    property string _notificationDiagnosticMessage: "Notifications are available."

    // id → { notification: NotificationObject, timer: Timer }
    property var _activeNotifications: ({})

    readonly property string _cacheDir: {
        var cacheHome = Quickshell.env("XDG_CACHE_HOME")
        var home = Quickshell.env("HOME")
        if (cacheHome && cacheHome !== "null" && cacheHome !== "/home/null") {
            return cacheHome + "/DymicShell/"
        }
        if (home && home !== "null" && home !== "/home/null") {
            return home + "/.cache/DymicShell/"
        }
        return "/tmp/DymicShell/"
    }

    readonly property string _historyFile: _cacheDir + "notifications.json"
    readonly property string _notificationOwnerCommand:
        "busctl --user status org.freedesktop.Notifications 2>/dev/null"

    // --- Notification server ---

    NotificationServer {
        id: _notificationServer
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        onNotification: (n) => root._handleNotification(n)
    }

    Process {
        id: _notificationOwnerProcess
        command: ["sh", "-c", root._notificationOwnerCommand]
        property string _buffer: ""

        stdout: SplitParser {
            onRead: (line) => {
                _notificationOwnerProcess._buffer += line + "\n"
            }
        }

        onExited: () => {
            root._applyNotificationOwnerOutput(_notificationOwnerProcess._buffer)
            _notificationOwnerProcess._buffer = ""
        }
    }

    // --- History persistence ---

    FileView {
        id: _historyFileView
        path: root._historyFile
        // text() is a method, not a signal parameter — call it explicitly.
        onLoaded: root._loadHistory(_historyFileView.text())
        onLoadFailed: root._scheduleSave()
    }

    Timer {
        id: _saveTimer
        interval: 300
        repeat: false
        onTriggered: root._writeToDisk()
    }

    // --- Timer component for auto-dismiss ---

    Component {
        id: _dismissTimerComponent
        Timer {
            property string notifId: ""
            repeat: false
            onTriggered: root.dismissActive(notifId)
        }
    }

    // --- Internal logic ---

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", _cacheDir])
        _refreshNotificationDiagnostics()
    }

    // --- Public API ---

    // Dismiss a popup notification without removing it from history.
    function dismissActive(id) {
        var idx = _findActive(id);
        if (idx < 0) return;
        _stopTimer(id);
        activeList.remove(idx);
    }

    function dismissAllActive() {
        while (activeList.count > 0) {
            var id = activeList.get(0).id;
            dismissActive(id)
        }
    }

    // Invoke a notification action then dismiss the popup.
    function invokeAction(id, identifier) {
        var entry = _activeNotifications[id];
        if (entry && entry.notification && entry.notification.actions) {
            for (var i = 0; i < entry.notification.actions.length; i++) {
                if (entry.notification.actions[i].identifier === identifier) {
                    entry.notification.actions[i].invoke();
                    break;
                }
            }
        }
        dismissActive(id);
    }

    function invokeDefaultAction(id) {
        var entry = _activeNotifications[id]
        if (!entry || !entry.notification)
            return false

        if (entry.notification.defaultAction) {
            entry.notification.defaultAction.invoke()
            dismissActive(id)
            return true
        }

        if (entry.notification.actions) {
            for (var index = 0; index < entry.notification.actions.length; index++) {
                if (entry.notification.actions[index].identifier === "default") {
                    entry.notification.actions[index].invoke()
                    dismissActive(id)
                    return true
                }
            }
        }

        return false
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

    // Pause auto-dismiss timer while the cursor hovers the card.
    function pauseTimer(id) {
        var entry = _activeNotifications[id];
        if (entry && entry.timer) entry.timer.running = false;
    }

    // Resume auto-dismiss timer when cursor leaves the card.
    function resumeTimer(id) {
        var entry = _activeNotifications[id];
        if (entry && entry.timer) entry.timer.running = true;
    }

    function _handleNotification(n) {
        var data = _buildData(n);

        // Always append to history unless transient
        if (!n.transient) {
            _prependHistory(data);
        }

        root.notificationReceived(data)

        if (root.doNotDisturb) return;

        if (!root.popupPresentationEnabled) return;

        // Store the live notification object so invokeAction() can reach its actions.
        if (!_activeNotifications[data.id]) _activeNotifications[data.id] = {};
        _activeNotifications[data.id].notification = n;

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
    }

    Connections {
        target: SettingsService.data.superIsland

        function onShowNotificationsChanged() {
            if (SettingsService.data.superIsland.showNotifications)
                root.dismissAllActive()
        }
    }

    function _refreshNotificationDiagnostics() {
        _notificationOwnerProcess.running = false
        _notificationOwnerProcess._buffer = ""
        _notificationOwnerProcess.running = true
    }

    function _applyNotificationOwnerOutput(output) {
        let owner = ""
        let lines = output ? output.split("\n") : []

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim()
            if (line.startsWith("Name=")) {
                owner = line.substring(5).trim()
                break
            }
            if (line.startsWith("Unit=") && owner === "") {
                owner = line.substring(5).trim()
            }
        }

        if (owner === "") {
            root._notificationsAvailable = true
            root._notificationOwner = ""
            root._notificationDiagnosticMessage = "Notifications are available."
            return
        }

        let normalizedOwner = owner
        if (normalizedOwner.endsWith(".service")) {
            normalizedOwner = normalizedOwner.slice(0, -8)
        }

        let selfOwnsNotifications = normalizedOwner === "quickshell"
            || normalizedOwner === "Quickshell"

        root._notificationsAvailable = selfOwnsNotifications
        root._notificationOwner = normalizedOwner
        root._notificationDiagnosticMessage = selfOwnsNotifications
            ? "Notifications are available."
            : "Another notification daemon is active: " + normalizedOwner + ". Stop it if you want DymicShell to take over notifications."
    }

    function _buildData(n) {
        var actions = [];
        if (n.actions) {
            for (var i = 0; i < n.actions.length; i++) {
                actions.push({ identifier: n.actions[i].identifier, text: n.actions[i].text });
            }
        }
        return {
            id:          String(n.id),
            appName:     n.appName  || "",
            summary:     n.summary  || "",
            body:        n.body     || "",
            appIcon:     n.appIcon  || "",
            urgency:     (n.urgency >= 0 && n.urgency <= 2) ? n.urgency : 1,
            timestamp:   Date.now(),
            actionsJson: JSON.stringify(actions)
        };
    }

    function _startTimer(data) {
        var d = SettingsService.data.notifications;
        var durations = [
            d.lowDuration      !== undefined ? d.lowDuration      : 3000,
            d.normalDuration   !== undefined ? d.normalDuration   : 5000,
            d.criticalDuration !== undefined ? d.criticalDuration : 0
        ];
        var ms = durations[data.urgency];
        if (ms <= 0) return;

        var t = _dismissTimerComponent.createObject(root, { notifId: data.id, interval: ms });
        t.start();
        if (!_activeNotifications[data.id]) _activeNotifications[data.id] = {};
        _activeNotifications[data.id].timer = t;
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
            _saveTimer.restart();
        }
    }

    function _writeToDisk() {
        var items = [];
        for (var i = 0; i < historyList.count; i++) {
            items.push(historyList.get(i));
        }
        var payload = JSON.stringify({ lastSeenTimestamp: _lastSeenTimestamp, items: items }, null, 2);
        _historyFileView.setText(payload);
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

    IpcHandler {
        target: "notifications"

        function toggleHistory() {
            BarLayoutService.notificationHistoryOpen = !BarLayoutService.notificationHistoryOpen
            if (BarLayoutService.notificationHistoryOpen)
                root.markAllSeen()
        }
        function toggleDND() { root.doNotDisturb = !root.doNotDisturb }
        function clear() {
            root.clearHistory()
            root._unreadCount = 0
        }
    }
}
