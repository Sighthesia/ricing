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
        + "/dymicshell"
    readonly property string _shellDirFile: _cacheDir + "/current-shell-dir"

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
        IslandOverlayService.toggleOverlay("launcher", "launcher", "");
    }

    function close() {
        IslandOverlayService.closeOverlay("launcher")
    }

    function openClipboard() {
        IslandOverlayService.openOverlay("launcher", ">clip ");
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
            if (IslandOverlayService.mode === "launcher" && IslandOverlayService.modePayload !== undefined) {
                root.prefillText = typeof IslandOverlayService.modePayload === "string"
                    ? IslandOverlayService.modePayload
                    : ""
                return
            }

            if (IslandOverlayService.mode !== "launcher")
                root.prefillText = ""
        }

        function onStateChanged() {
            if (IslandOverlayService.mode === "launcher" && IslandOverlayService.state === "closing")
                root.prefillText = ""

            if (IslandOverlayService.mode === "none")
                root.prefillText = ""
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() { root.toggle(); }
        function openClipboard() { root.openClipboard(); }
    }
}
