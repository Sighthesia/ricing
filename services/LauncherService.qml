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
    readonly property string _cacheDir:
        (Quickshell.env("XDG_CACHE_HOME") !== ""
            ? Quickshell.env("XDG_CACHE_HOME")
            : Quickshell.env("HOME") + "/.cache")
        + "/DymicShell"
    readonly property string _shellDirFile: _cacheDir + "/current-shell-dir"

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

    Timer {
        id: _publishShellDirTimer
        interval: 0
        repeat: false
        onTriggered: root._publishShellDir()
    }

    Process {
        id: _shellDirWriter

        stdinEnabled: true
        command: ["sh", "-c", "mkdir -p '" + root._cacheDir + "' && cat > '" + root._shellDirFile + "'"]
    }

    function toggle() {
        root._log("toggle requested")
        root.prefillText = ""
        IslandOverlayService.openOverlay("launcher", "")
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

    function _publishShellDir(): void {
        console.info("[DymicShell:LauncherService] Publishing shell directory", Quickshell.shellDir)
        _shellDirWriter.running = false
        _shellDirWriter.running = true
        _shellDirWriter.write(Quickshell.shellDir + "\n")
    }

    Component.onCompleted: {
        _publishShellDirTimer.start()
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
