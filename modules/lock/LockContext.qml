pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Own the password conversation and expose only its transient UI state.
Scope {
    id: root

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string errorMessage: ""

    signal unlocked()
    signal failed()

    function start(): bool {
        if (unlockInProgress || pam.active)
            return false

        showFailure = false
        errorMessage = ""
        unlockInProgress = pam.start()
        return unlockInProgress
    }

    function reset(): void {
        pam.abort()
        currentText = ""
        unlockInProgress = false
        showFailure = false
        errorMessage = ""
    }

    // Keep the PAM conversation isolated from the surface that renders it.
    PamContext {
        id: pam

        config: "passwd"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onResponseRequiredChanged: {
            if (!responseRequired)
                return

            respond(root.currentText)
            root.currentText = ""
        }

        onCompleted: result => {
            root.unlockInProgress = false
            root.currentText = ""

            if (result === PamResult.Success) {
                root.showFailure = false
                root.errorMessage = ""
                root.unlocked()
                return
            }

            root.showFailure = true
            root.errorMessage = pam.message
            root.failed()
        }

        onError: error => {
            root.unlockInProgress = false
            root.currentText = ""
            root.showFailure = true
            root.errorMessage = PamError.toString(error)
            root.failed()
        }
    }
}
