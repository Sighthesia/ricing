pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// Shared state and command execution for the fullscreen session control surface.
Singleton {
    id: root

    property string source: ""
    property string phase: "closed"
    property string selectedAction: "logout"
    property string confirmingAction: ""
    property string executingAction: ""
    property string lastError: ""

    property var _pendingCommand: []
    property string _stdoutBuffer: ""
    property string _stderrBuffer: ""

    readonly property bool overlayVisible:
        IslandOverlayService.mode === "session-control"
        && IslandOverlayService.state !== "closed"
    readonly property bool busy: _actionProcess.running || root.phase === "executing"

    function openSessionControl(source) {
        root.source = source || ""
        root.phase = "browse"
        root.selectedAction = "logout"
        root.confirmingAction = ""
        root.executingAction = ""
        root.lastError = ""
        IslandOverlayService.openOverlay("session-control", {
            source: root.source
        })
        return true
    }

    function closeSessionControl(reason) {
        if (root.busy)
            return false

        if (root.overlayVisible)
            IslandOverlayService.closeOverlay(reason || "session-control")
        else
            root._resetState()
        return true
    }

    function toggleSessionControl(source) {
        if (root.overlayVisible)
            return root.closeSessionControl("toggle")

        return root.openSessionControl(source)
    }

    function previewAction(actionId) {
        if (!actionId)
            return false

        root.selectedAction = actionId
        return true
    }

    function isDangerousAction(actionId) {
        return actionId === "logout" || actionId === "shutdown" || actionId === "reboot"
    }

    function beginDangerConfirmation(actionId) {
        if (!actionId || root.busy || !root.isDangerousAction(actionId))
            return false

        root.selectedAction = actionId
        root.confirmingAction = actionId
        root.executingAction = ""
        root.lastError = ""
        root.phase = "confirm"
        return true
    }

    function cancelDangerConfirmation() {
        if (root.busy)
            return false

        root.confirmingAction = ""
        root.executingAction = ""
        root.lastError = ""
        if (root.overlayVisible)
            root.phase = "browse"
        return true
    }

    function handleEscape() {
        if (root.phase === "confirm")
            return root.cancelDangerConfirmation()

        return root.closeSessionControl("escape")
    }

    function executeAction(actionId) {
        const normalizedAction = (actionId || root.confirmingAction || root.selectedAction || "").trim()
        const command = root._commandForAction(normalizedAction)

        if (normalizedAction === "" || root.busy || command.length === 0)
            return false

        root.selectedAction = normalizedAction
        root.executingAction = normalizedAction
        root.lastError = ""
        root._pendingCommand = command
        root.phase = "executing"

        console.info(
            "[DymicShell:SessionControlService] Executing",
            normalizedAction,
            command.join(" ")
        )

        _actionProcess.running = true
        return true
    }

    function _commandForAction(actionId) {
        switch (actionId) {
        case "logout":
            return [
                "sh",
                "-c",
                "session_id=\"${XDG_SESSION_ID:-}\"; user_name=\"${USER:-}\"; "
                + "if [ -n \"$session_id\" ]; then exec loginctl terminate-session \"$session_id\"; "
                + "elif [ -n \"$user_name\" ]; then exec loginctl terminate-user \"$user_name\"; "
                + "else exit 1; fi"
            ]
        case "shutdown":
            return ["systemctl", "poweroff"]
        case "reboot":
            return ["systemctl", "reboot"]
        case "suspend":
            return ["systemctl", "suspend"]
        default:
            return []
        }
    }

    function _restoreAfterExit(exitCode) {
        if (exitCode === 0) {
            if (root.executingAction === "suspend")
                root.closeSessionControl("suspend-finished")
            return
        }

        root.lastError = (root._stderrBuffer || root._stdoutBuffer || "command failed").trim()
        console.warn(
            "[DymicShell:SessionControlService] Command failed",
            root.executingAction,
            "exitCode=",
            exitCode,
            root.lastError
        )

        if (root.isDangerousAction(root.executingAction)) {
            root.confirmingAction = root.executingAction
            root.phase = "confirm"
        } else {
            root.confirmingAction = ""
            root.phase = "browse"
        }

        root.executingAction = ""
    }

    function _resetState() {
        root.source = ""
        root.phase = "closed"
        root.selectedAction = "logout"
        root.confirmingAction = ""
        root.executingAction = ""
        root.lastError = ""
    }

    Process {
        id: _actionProcess

        command: root._pendingCommand
        running: false

        stdout: SplitParser {
            onRead: (line) => root._stdoutBuffer += line + "\n"
        }

        stderr: SplitParser {
            onRead: (line) => root._stderrBuffer += line + "\n"
        }

        onExited: (exitCode, exitStatus) => {
            root._restoreAfterExit(exitCode)
            root._pendingCommand = []
            root._stdoutBuffer = ""
            root._stderrBuffer = ""
        }
    }

    Connections {
        target: IslandOverlayService

        function onModeChanged() {
            if (IslandOverlayService.mode === "session-control") {
                if (root.phase === "closed")
                    root.phase = "browse"
                return
            }

            root._resetState()
        }

        function onStateChanged() {
            if (IslandOverlayService.mode === "session-control")
                return

            if (IslandOverlayService.state === "closed")
                root._resetState()
        }
    }

    IpcHandler {
        target: "sessionMenu"

        function toggle() { root.toggleSessionControl("ipc") }
    }
}
