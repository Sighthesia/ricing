pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Central state for the launcher panel.
// Opened/closed by external IPC or internal code — no bar widget.
Singleton {
    id: root

    readonly property bool isOpen:
        IslandOverlayService.mode === "launcher"
        && (IslandOverlayService.state === "opening" || IslandOverlayService.state === "open")
    // Text to prefill in the search box when opening via IPC.
    property string prefillText: ""
    function _log(message) {
        console.info("[DymicShell:LauncherService]", message,
            "mode=", IslandOverlayService.mode,
            "state=", IslandOverlayService.state,
            "payload=", IslandOverlayService.modePayload,
            "prefill=", root.prefillText)
    }

    function _syncPrefillFromOverlay() {
        if (IslandOverlayService.mode === "launcher") {
            root.prefillText = typeof IslandOverlayService.modePayload === "string"
                ? IslandOverlayService.modePayload
                : ""
            root._log("synced launcher prefill")
            return
        }

        if (IslandOverlayService.mode === "none" || IslandOverlayService.state === "closing") {
            root.prefillText = ""
            root._log("cleared launcher prefill")
        }
    }

    function ensureInitialized() {
        root._log("initialized")
    }

    function toggle() {
        root._log("toggle requested")
        root.prefillText = ""
        IslandOverlayService.toggleOverlay("launcher", "launcher", "")
    }

    function close() {
        root._log("close requested")
        IslandOverlayService.closeOverlay("launcher")
    }

    function openClipboard() {
        root._log("clipboard requested")
        root.prefillText = ">clip "
        IslandOverlayService.openOverlay("launcher", ">clip ")
    }

    Component.onCompleted: {
        root.ensureInitialized()
    }

    Connections {
        target: IslandOverlayService

        function onModeChanged() {
            root._syncPrefillFromOverlay()
        }

        function onStateChanged() {
            root._syncPrefillFromOverlay()
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() { root.toggle(); }
        function openClipboard() { root.openClipboard(); }
    }
}
