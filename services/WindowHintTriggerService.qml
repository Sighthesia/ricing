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

    // ---- live key state ---------------------------------------------------
    //
    // The helper reports every key event with the modifiers that were held while
    // it happened ("key <evdev code> <value> <mask>"), and a bare `syn` when the
    // kernel frame is complete. That is the only place in the shell that knows
    // which keys are physically down, because a Wayland client cannot see a
    // keybinding the compositor has intercepted - which is exactly what the
    // shortcut the user is pressing is.
    //
    // Keys are buffered until `syn` and published as one frame, so a consumer
    // never sees half a key press: the modifier that arrived with it and the key
    // itself belong to the same moment.
    property var liveModifiers: ({ "mask": 0, "shift": false, "ctrl": false, "alt": false, "super": false, "iso5": false })
    property var liveKeyCodes: []
    // Emitted once per key frame. `pressed` / `released` are the code of the key
    // that changed in THIS frame, or -1: a frame can carry several keys (a
    // modifier and a letter arriving together), so the consumer is told the
    // whole held set and which single key moved.
    signal keyFrame(var frame)

    signal holdChanged(bool active)

    // One entry per modifier bit the helper's mask uses, in its order (see
    // `MODIFIER_GROUPS` in `scripts/window_hint_trigger.py`).
    function _decodeMask(mask) {
        const value = Number(mask) | 0
        return {
            "mask": value,
            "shift": (value & 1) !== 0,
            "ctrl": (value & 2) !== 0,
            "alt": (value & 4) !== 0,
            "super": (value & 8) !== 0,
            "iso5": (value & 16) !== 0
        }
    }

    property var _frameKeyCodes: ({})
    property int _framePressed: -1
    property int _frameReleased: -1
    property int _frameValue: -1

    function _handleKeyEvent(code, value, mask) {
        const keyCode = Number(code)
        if (!isFinite(keyCode))
            return

        const pressed = Number(value)
        if (pressed === 1 || pressed === 2)
            root._frameKeyCodes[keyCode] = true
        else
            delete root._frameKeyCodes[keyCode]

        root._framePressed = pressed === 1 ? keyCode : -1
        root._frameReleased = pressed === 0 ? keyCode : -1
        root._frameValue = pressed
        root.liveModifiers = root._decodeMask(mask)

        // A press has to reach the consumer even if the kernel frame is never
        // closed (a device that stops mid-frame). Reported here as an immediate
        // frame as well; the `syn` below then reports the settled set, and a
        // consumer that only cares about presses sees one press per key.
        if (pressed === 1)
            root._emitKeyFrame()
    }

    function _emitKeyFrame() {
        const codes = []
        for (const code in root._frameKeyCodes)
            codes.push(Number(code))
        codes.sort((left, right) => left - right)

        root.liveKeyCodes = codes
        root.keyFrame({
            "codes": codes,
            "modifiers": root.liveModifiers,
            "pressed": root._framePressed,
            "released": root._frameReleased,
            "value": root._frameValue
        })
        root._framePressed = -1
        root._frameReleased = -1
    }

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
        const raw = (line || "").trim()
        const normalized = raw.toLowerCase()
        if (normalized === "")
            return

        // Key events and frame boundaries, before the hold vocabulary below:
        // these carry arguments, so they are not single words.
        if (normalized.indexOf("key ") === 0) {
            const parts = raw.split(/\s+/)
            if (parts.length >= 4)
                root._handleKeyEvent(parts[1], parts[2], parts[3])
            return
        }

        if (normalized === "syn") {
            root._emitKeyFrame()
            return
        }

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
            // The keyboard is gone: whatever was held was released with it.
            root._frameKeyCodes = ({})
            root.liveKeyCodes = []
            root.liveModifiers = root._decodeMask(0)

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
