pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Central state for the launcher panel.
// Opened/closed by external IPC or internal code — no bar widget.
Singleton {
    id: root

    property bool isOpen: false
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

    FileView {
        id: _shellDirFileView
        path: root._shellDirFile
    }

    function toggle(): void {
        if (root.isOpen) {
            root.prefillText = "";
            root.isOpen = false;
        } else {
            root.prefillText = "";
            root.isOpen = true;
        }
    }

    function openClipboard(): void {
        root.prefillText = ">clip ";
        root.isOpen = true;
    }

    function _publishShellDir(): void {
        console.info("[DymicShell:LauncherService] Publishing shell directory", Quickshell.shellDir)
        _shellDirFileView.setText(Quickshell.shellDir)
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root._cacheDir])
        _publishShellDirTimer.start()
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle(); }
        function openClipboard(): void { root.openClipboard(); }
    }
}
