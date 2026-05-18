pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Bridges external mod-key press/release events into a shared hint-held signal.
Singleton {
    id: root

    readonly property string _triggerScriptPath: Quickshell.shellDir + "/scripts/window_hint_trigger.py"
    readonly property string _helperOverride: (Quickshell.env("AFLOAT_WINDOW_HINT_TRIGGER_CMD") || "").trim()
    readonly property bool _bundledHelperDisabled:
        (Quickshell.env("AFLOAT_WINDOW_HINT_TRIGGER_DISABLE") || "").trim() === "1"
    readonly property string _configuredMetaKeys: (Quickshell.env("AFLOAT_WINDOW_HINT_META_KEYS") || "").trim()
    readonly property string _escapedMetaKeys: root._configuredMetaKeys.replace(/'/g, "'\"'\"'")
    readonly property string _bundledHelperCommand:
        "export AFLOAT_WINDOW_HINT_META_KEYS='"
        + root._escapedMetaKeys
        + "'; if command -v python3 >/dev/null 2>&1; then exec python3 '"
        + root._triggerScriptPath
        + "'; else exit 0; fi"
    readonly property string helperCommand:
        root._helperOverride !== ""
            ? root._helperOverride
            : (root._bundledHelperDisabled ? "" : root._bundledHelperCommand)
    readonly property bool available: helperCommand !== ""
    readonly property bool running: _bridgeProcess.running

    property bool active: false
    property string lastEvent: ""

    signal holdChanged(bool active)

    function _applyHold(nextActive, eventName) {
        const normalizedActive = !!nextActive
        const normalizedEvent = (eventName || "").trim()

        root.lastEvent = normalizedEvent
        if (root.active === normalizedActive) {
            if (normalizedEvent !== "")
                root.holdChanged(root.active)
            return
        }

        root.active = normalizedActive
        root.holdChanged(root.active)
    }

    function _handleLine(line) {
        const normalized = (line || "").trim().toLowerCase()
        if (normalized === "")
            return

        switch (normalized) {
        case "mod-down":
        case "down":
        case "show":
        case "hold":
        case "1":
        case "true":
            root._applyHold(true, normalized)
            return
        case "mod-up":
        case "up":
        case "hide":
        case "release":
        case "0":
        case "false":
            root._applyHold(false, normalized)
            return
        case "toggle":
            root._applyHold(!root.active, normalized)
            return
        default:
            console.warn("[afloat:WindowHintTriggerService] Ignoring unknown trigger event", normalized)
            return
        }
    }

    Component.onCompleted: {
        if (root.available)
            _bridgeProcess.running = true
    }

    Process {
        id: _bridgeProcess

        command: ["sh", "-c", root.helperCommand]
        running: false

        stdout: SplitParser {
            onRead: (line) => root._handleLine(line)
        }

        onExited: () => {
            if (root.active)
                root._applyHold(false, "process-exit")

            if (root.available)
                _restartTimer.restart()
        }
    }

    Timer {
        id: _restartTimer

        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.available || _bridgeProcess.running)
                return

            _bridgeProcess.running = true
        }
    }
}
