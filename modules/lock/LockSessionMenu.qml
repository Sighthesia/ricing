import QtQuick
import "../lazerbar" as Lazer
import "LockSessionMenuLogic.js" as Logic

// Present the session actions as a bounded Wave-style lock-screen surface.
Item {
    id: root

    property bool open: false
    property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    property var sessionService: null
    property string errorText: ""
    property string statusText: ""
    property string pendingAction: ""
    // The lock surface supplies a discrete gate at the trailing wave edge.
    // The menu's own open/close progress remains independent from this gate.
    property bool entranceRevealed: true
    property real revealProgress: 0
    readonly property int menuItemCount: actionColumn.children.length
    readonly property int panelHeight: 296

    signal escapeHandled(bool handled)

    implicitWidth: 332
    implicitHeight: panelHeight + 56
    width: implicitWidth
    height: implicitHeight
    visible: root.entranceRevealed
    enabled: root.entranceRevealed

    function toggleOpen(): void {
        root.open = Logic.toggle(root.open)
    }

    function setOpen(nextOpen): void {
        root.open = nextOpen === true
    }

    function syncReveal(): void {
        revealAnimation.stop()
        if (root.reducedMotion) {
            root.revealProgress = root.open ? 1 : 0
            return
        }
        revealAnimation.from = root.revealProgress
        revealAnimation.to = root.open ? 1 : 0
        revealAnimation.restart()
    }

    function actionAvailable(actionId): bool {
        return root.sessionService && root.sessionService.isAvailable
                ? root.sessionService.isAvailable(actionId) : false
    }

    function activateAction(actionId): void {
        if (!root.sessionService)
            return
        const available = actionAvailable(actionId)
        const decision = Logic.confirmationAction(root.open, root.pendingAction, actionId)
        if (decision === "pending" || !Logic.canTrigger(actionId, available,
                                                          root.sessionService.running))
            return

        if (decision === "confirm" || actionId === "lock") {
            if (actionId === "lock")
                root.open = false
            if (root.sessionService.execute(actionId)) {
                root.pendingAction = ""
                root.statusText = ""
            }
            return
        }

        root.pendingAction = actionId
        root.statusText = "Select again to confirm"
    }

    function handleEscape(): bool {
        const action = Logic.escapeAction(root.open, root.pendingAction)
        if (action === "cancel-confirmation") {
            root.pendingAction = ""
            root.statusText = ""
        } else if (action === "close") {
            root.open = false
        } else {
            return false
        }
        escapeHandled(true)
        return true
    }

    function syncServiceMessage(): void {
        if (!root.sessionService)
            return
        root.errorText = String(root.sessionService.errorText || "")
        root.statusText = root.errorText || String(root.sessionService.resultText || "")
    }

    onOpenChanged: syncReveal()
    onReducedMotionChanged: syncReveal()
    onSessionServiceChanged: {
        serviceConnections.target = root.sessionService
        syncServiceMessage()
    }

    // Keep the host fixed while the clipped panel sweeps in from the side.
    Item {
        id: panelHost
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.panelHeight
        visible: root.open || root.revealProgress > 0.01
        enabled: root.open

        Item {
            id: revealClip
            anchors.right: parent.right
            anchors.top: parent.top
            width: panelHost.width * root.revealProgress
            height: panelHost.height
            clip: true

            Rectangle {
                id: panel
                x: revealClip.width - width
                y: (1 - root.revealProgress) * 12
                width: panelHost.width
                height: panelHost.height
                color: Lazer.LazerTheme.settingsPanel
                border.width: 1
                border.color: Lazer.LazerTheme.divider

                // Identify the session surface without adding a rounded container.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 4
                    color: Lazer.LazerTheme.osuPink
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    text: "SESSION"
                    color: Lazer.LazerTheme.textMuted
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.top: parent.top
                    anchors.topMargin: 36
                    width: parent.width - 36
                    text: root.errorText || root.statusText
                    visible: text.length > 0
                    color: root.errorText ? Lazer.LazerTheme.osuPink : Lazer.LazerTheme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                // Static rows keep all visual children inside the lock surface.
                Column {
                    id: actionColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    spacing: 1

                    LockSessionMenuItem {
                        id: lockItem
                        width: actionColumn.width - 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        actionId: "lock"
                        label: "Lock"
                        iconSource: "L"
                        menuHost: root
                        available: root.actionAvailable(actionId)
                        running: root.sessionService ? root.sessionService.running : false
                        onActivated: actionId => root.activateAction(actionId)
                    }

                    LockSessionMenuItem {
                        id: logoutItem
                        width: actionColumn.width - 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        actionId: "logout"
                        label: "Log out"
                        iconSource: "X"
                        menuHost: root
                        available: root.actionAvailable(actionId)
                        confirmationPending: root.pendingAction === actionId
                        running: root.sessionService ? root.sessionService.running : false
                        onActivated: actionId => root.activateAction(actionId)
                    }

                    LockSessionMenuItem {
                        id: suspendItem
                        width: actionColumn.width - 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        actionId: "suspend"
                        label: "Suspend"
                        iconSource: "S"
                        menuHost: root
                        available: root.actionAvailable(actionId)
                        confirmationPending: root.pendingAction === actionId
                        running: root.sessionService ? root.sessionService.running : false
                        onActivated: actionId => root.activateAction(actionId)
                    }

                    LockSessionMenuItem {
                        id: rebootItem
                        width: actionColumn.width - 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        actionId: "reboot"
                        label: "Reboot"
                        iconSource: "R"
                        menuHost: root
                        available: root.actionAvailable(actionId)
                        confirmationPending: root.pendingAction === actionId
                        running: root.sessionService ? root.sessionService.running : false
                        onActivated: actionId => root.activateAction(actionId)
                    }

                    LockSessionMenuItem {
                        id: shutdownItem
                        width: actionColumn.width - 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        actionId: "shutdown"
                        label: "Shut down"
                        iconSource: "P"
                        menuHost: root
                        available: root.actionAvailable(actionId)
                        confirmationPending: root.pendingAction === actionId
                        running: root.sessionService ? root.sessionService.running : false
                        onActivated: actionId => root.activateAction(actionId)
                    }
                }
            }
        }
    }

    // Use a compact rectangular trigger that never covers the password field.
    Rectangle {
        id: trigger
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 152
        height: 48
        color: root.open ? Lazer.LazerTheme.activeFill : Lazer.LazerTheme.settingsControlSurface
        border.width: root.activeFocus ? 1 : 0
        border.color: Lazer.LazerTheme.focusRing
        Text {
            anchors.centerIn: parent
            text: root.open ? "CLOSE" : "SESSION"
            color: Lazer.LazerTheme.textPrimary
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1
        }
        TapHandler {
            onTapped: {
                root.toggleOpen()
            }
        }
        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: Lazer.MotionTokens.fast }
        }
    }

    NumberAnimation {
        id: revealAnimation
        target: root
        property: "revealProgress"
        duration: Lazer.MotionTokens.medium
        easing.type: Easing.OutQuint
        running: false
    }

    Connections {
        id: serviceConnections
        target: null
        function onActionFinished(actionId, success, message) {
            root.pendingAction = ""
            root.errorText = success ? "" : String(message || "Session action failed")
            root.statusText = String(message || "")
        }
        function onErrorTextChanged() { root.syncServiceMessage() }
        function onResultTextChanged() { root.syncServiceMessage() }
    }

    Keys.onEscapePressed: event => {
        event.accepted = root.handleEscape()
    }
}
