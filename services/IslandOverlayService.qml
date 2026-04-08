pragma Singleton

import Quickshell
import QtQuick

// Shared overlay state for the paged SuperIsland expansion bridge.
// Owns the logical overlay contract; geometry and host rendering stay elsewhere.
Singleton {
    id: root

    property string mode: "none"
    property string state: "closed"
    property real backdropProgress: 0
    property real rippleProgress: 0
    property var modePayload: null

    function openOverlay(mode, payload) {
        let nextMode = _normalizeMode(mode)
        if (!nextMode)
            return false

        let nextState = root.state === "closed" || root.mode === "none"
            ? "opening"
            : (root.state === "closing" ? "opening" : "open")

        _applyOverlay(nextMode, payload, nextState)
        return true
    }

    function closeOverlay(reason) {
        if (root.state === "closed" && root.mode === "none")
            return false

        root.state = "closing"
        root.backdropProgress = 0
        root.rippleProgress = 0

        return true
    }

    function toggleOverlay(mode, source, payload) {
        let nextMode = _normalizeMode(mode)
        if (!nextMode)
            return false

        if (root.state === "closed" || root.mode === "none") {
            _applyOverlay(nextMode, payload, "opening")
            return true
        }

        if (root.state === "closing") {
            _applyOverlay(nextMode, payload, "opening")
            return true
        }

        if (root.mode !== nextMode) {
            _applyOverlay(nextMode, payload, root.state === "open" ? "open" : "opening")
            return true
        }

        if (root.state === "open" || root.state === "opening") {
            closeOverlay(source)
            return true
        }

        return false
    }

    function retargetOverlay(mode, payload) {
        let nextMode = _normalizeMode(mode)
        if (!nextMode)
            return false

        _applyOverlay(nextMode, payload, root.state === "closing" ? "opening" : root.state)
        return true
    }

    function setSettledState(mode, state) {
        let nextMode = _normalizeMode(mode)
        let nextState = _normalizeState(state)

        if (!nextMode || !nextState)
            return false

        root.mode = nextMode
        root.state = nextState

        if (nextState === "closed") {
            root.mode = "none"
            root.modePayload = null
            root.backdropProgress = 0
            root.rippleProgress = 0
        } else if (nextState === "opening" || nextState === "open") {
            root.backdropProgress = 1
            root.rippleProgress = 1
        } else if (nextState === "closing") {
            root.backdropProgress = 0
            root.rippleProgress = 0
        }

        return true
    }

    function _applyOverlay(mode, payload, nextState) {
        root.mode = mode
        root.modePayload = payload === undefined ? null : payload
        root.state = nextState

        if (nextState === "opening" || nextState === "open") {
            root.backdropProgress = 1
            root.rippleProgress = 1
        } else if (nextState === "closing") {
            root.backdropProgress = 0
            root.rippleProgress = 0
        } else {
            root.backdropProgress = 0
            root.rippleProgress = 0
        }
    }

    function _normalizeMode(mode) {
        if (mode === "launcher"
                || mode === "settings"
                || mode === "control-center"
                || mode === "notifications"
                || mode === "break-reminder")
            return mode

        return ""
    }

    function _normalizeState(state) {
        if (state === "closed" || state === "opening" || state === "open" || state === "closing")
            return state

        return ""
    }
}
