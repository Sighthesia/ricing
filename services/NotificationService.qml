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
        // text() is a method, not a signal parameter — call it explicitly.
        onLoaded: root._loadHistory(historyFileView.text())
        onLoadFailed: root._scheduleSave()
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

        // Always append to history unless transient
        if (!n.transient) {
            _prependHistory(data);
        }

        if (root.doNotDisturb) return;

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

        var t = dismissTimerComponent.createObject(root, { notifId: data.id, interval: ms });
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
