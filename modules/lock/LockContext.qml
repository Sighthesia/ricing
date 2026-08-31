pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import "./LockLogic.js" as LockLogic

// Own the password conversation and expose only its transient UI state.
Scope {
    id: root

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string errorMessage: ""
    property bool failureReported: false
    property bool waitingForPassword: false

    signal unlocked()
    signal failed()

    function start(): bool {
        if (unlockInProgress || pam.active)
            return false

        showFailure = false
        errorMessage = ""
        failureReported = false
        waitingForPassword = false
        unlockInProgress = pam.start()
        return unlockInProgress
    }

    function submit(): bool {
        if (unlockInProgress)
            return false
        if (waitingForPassword) {
            waitingForPassword = false
            pam.respond(currentText)
            currentText = ""
            unlockInProgress = true
            return true
        }
        return start()
    }

    function reset(): void {
        pam.abort()
        currentText = ""
        unlockInProgress = false
        showFailure = false
        errorMessage = ""
        failureReported = false
        waitingForPassword = false
    }

    function reportFailure(message): void {
        var transition = LockLogic.failureTransition(failureReported, errorMessage, message)
        failureReported = true
        errorMessage = transition.message
        showFailure = true
        if (transition.shouldNotify)
            failed()
    }

    // Keep the PAM conversation isolated from the surface that renders it.
    PamContext {
        id: pam

        config: "passwd"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onResponseRequiredChanged: {
            if (!responseRequired)
                return

            if (root.currentText.length === 0) {
                root.waitingForPassword = true
                return
            }

            respond(root.currentText)
            root.currentText = ""
        }

        onCompleted: result => {
            root.unlockInProgress = false
            root.currentText = ""
            root.waitingForPassword = false

            if (result === PamResult.Success) {
                root.showFailure = false
                root.errorMessage = ""
                root.unlocked()
                return
            }

            root.reportFailure(pam.message)
        }

        onError: error => {
            root.unlockInProgress = false
            root.currentText = ""
            root.waitingForPassword = false
            root.reportFailure(PamError.toString(error))
        }
    }
}
