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

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle(); }
        function openClipboard(): void { root.openClipboard(); }
    }
}
