pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "SessionServiceLogic.js" as Logic

// Route session-level commands through one process and one in-flight gate.
Singleton {
    id: root

    readonly property bool running: actionProcess.running
    readonly property string runningAction: _runningAction
    readonly property string errorText: _errorText
    readonly property string resultText: _resultText
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || ""

    property string _runningAction: ""
    property string _errorText: ""
    property string _resultText: ""

    signal lockRequested()
    signal actionStarted(string actionId)
    signal actionFinished(string actionId, bool success, string message)

    function isKnownAction(actionId): bool {
        return Logic.isKnownAction(String(actionId || ""))
    }

    function isAvailable(actionId): bool {
        return Logic.isAvailable(String(actionId || ""), root.sessionId)
    }

    function clearMessage(): void {
        root._errorText = ""
        root._resultText = ""
    }

    function execute(actionId): bool {
        const id = String(actionId || "")
        if (!Logic.canStart(root.running, id, root.sessionId))
            return false

        root.clearMessage()
        root.actionStarted(id)

        if (id === "lock") {
            root.lockRequested()
            root._resultText = "Lock requested"
            root.actionFinished(id, true, root._resultText)
            return true
        }

        const command = Logic.commandFor(id, root.sessionId)
        if (!command.length)
            return false

        root._runningAction = id
        actionProcess.command = command
        actionProcess.running = true
        return true
    }

    // Own the command lifecycle so failures remain visible inside the menu.
    Process {
        id: actionProcess
        running: false

        onExited: (exitCode, exitStatus) => {
            const id = root._runningAction
            const success = Number(exitCode) === 0
            const message = success ? "" : "Session action failed"
            root._runningAction = ""
            if (success)
                root._resultText = id + " requested"
            else
                root._errorText = message
            root.actionFinished(id, success, success ? root._resultText : message)
        }
    }
}
