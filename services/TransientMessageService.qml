pragma Singleton
import QtQuick
import Quickshell
import "./" as Services

// Aggregate transient messages (notifications, volume, brightness, media) into
// one queued stream. Exposes `active` so dockzone widgets can simplify while a
// message shows, and `current` for the bar message band to render.
Singleton {
    id: root

    // Current message: { kind, glyph, icon, title, body, progress } or null.
    property var current: null
    readonly property bool active: current !== null
    property real revealProgress: active ? 1 : 0

    Behavior on revealProgress {
        NumberAnimation {
            duration: Services.Motion.number.contentDuration
            easing.type: Services.Motion.number.contentEasing
        }
    }

    // Suppress the initial property emissions (brightness poll, volume init)
    // that fire during startup so the band only appears on genuine changes.
    property bool _armed: false
    property Timer _armTimer: Timer {
        interval: 1500
        running: true
        onTriggered: root._armed = true
    }

    // Pending FIFO queue; each entry is a normalized message object.
    property var _queue: []
    // Coalescing key of the showing message so rapid repeats (volume drag)
    // refresh in place instead of stacking.
    property string _currentKey: ""
    property bool _betweenMessages: false

    // Push a message; keyed kinds coalesce, notifications always enqueue.
    function _push(msg) {
        if (!root._armed)
            return
        if (msg.key && root._currentKey === msg.key) {
            root.current = msg
            hideTimer.restart()
            return
        }
        var q = root._queue.slice()
        if (msg.key) {
            for (var i = 0; i < q.length; ++i) {
                if (q[i].key === msg.key) {
                    q[i] = msg
                    root._queue = q
                    return
                }
            }
        }
        q.push(msg)
        root._queue = q
        if (!root.active && !root._betweenMessages)
            _advance()
    }

    // Promote the next queued message and arm the hide timer.
    function _advance() {
        root._betweenMessages = false
        if (root._queue.length === 0) {
            root.current = null
            root._currentKey = ""
            hideTimer.stop()
            return
        }
        var q = root._queue.slice()
        var next = q.shift()
        root._queue = q
        root.current = next
        root._currentKey = next.key || ""
        hideTimer.restart()
    }

    // Per-message dwell: notifications linger, OSD feedback is brief.
    property Timer hideTimer: Timer {
        interval: root.current && root.current.kind === "notification" ? 5000 : 1800
        onTriggered: {
            if (root._queue.length === 0) {
                root._advance()
                return
            }

            root._betweenMessages = true
            root.current = null
            root._currentKey = ""
            nextMessageTimer.restart()
        }
    }

    property Timer nextMessageTimer: Timer {
        interval: Services.Motion.number.contentDuration + 40
        onTriggered: root._advance()
    }

    // --- Notifications ---
    property Connections _notifConn: Connections {
        target: Services.NotificationService.popupList
        function onRowsInserted(parent, first, last) {
            for (var i = first; i <= last; ++i) {
                var n = Services.NotificationService.popupList.get(i)
                root._push({
                    kind: "notification", key: "",
                    icon: n.icon || "", glyph: "",
                    appName: n.appName || "",
                    title: n.summary || n.appName || "",
                    body: n.body || "", progress: -1
                })
            }
        }
    }

    // --- Volume ---
    property Connections _volConn: Connections {
        target: Services.VolumeService
        function onSinkVolumeChanged() {
            root._push({
                kind: "volume", key: "volume", icon: "",
                glyph: Services.VolumeService.sinkMuted ? "🔇" : "🔊",
                title: Math.round(Services.VolumeService.sinkVolume * 100) + "%",
                body: "", progress: Services.VolumeService.sinkVolume
            })
        }
        function onSinkMutedChanged() {
            root._push({
                kind: "volume", key: "volume", icon: "",
                glyph: Services.VolumeService.sinkMuted ? "🔇" : "🔊",
                title: Services.VolumeService.sinkMuted ? "静音" : Math.round(Services.VolumeService.sinkVolume * 100) + "%",
                body: "", progress: Services.VolumeService.sinkMuted ? 0 : Services.VolumeService.sinkVolume
            })
        }
    }

    // --- Brightness ---
    property Connections _brightConn: Connections {
        target: Services.BrightnessService
        function onBrightnessChanged() {
            root._push({
                kind: "brightness", key: "brightness", icon: "", glyph: "☀",
                title: Math.round(Services.BrightnessService.brightness * 100) + "%",
                body: "", progress: Services.BrightnessService.brightness
            })
        }
    }

    // --- Media (track / playback change) ---
    property Connections _mediaConn: Connections {
        target: Services.MediaService
        function onPlayingChanged() {
            if (!Services.MediaService.title) return
            root._push({
                kind: "media", key: "media", icon: Services.MediaService.artUrl, appName: "",
                glyph: Services.MediaService.playing ? "▶" : "⏸",
                title: Services.MediaService.title,
                body: Services.MediaService.artist, progress: -1
            })
        }
    }
}
