import QtQuick
import "../lazerbar" as Lazer
import "LockActionBarLogic.js" as Logic
import "LockSurfaceLogic.js" as SurfaceLogic

// Present suspend, shut down and log out as one permanent row of buttons in the
// lower-right corner of the lock surface. There is no panel and no trigger: the
// buttons sit at the centered lock entry's own size, so the power controls read
// as peers of the lock glyph rather than as a separate menu.
Item {
    id: root

    property var sessionService: null
    property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    property bool lightScheme: false
    // One frozen palette for the whole lock cycle. Null only when the bar is
    // used standalone, in which case the live theme singleton is the source.
    property var lockTheme: null
    // The lock surface supplies a discrete gate at the trailing wave edge.
    property bool entranceRevealed: true
    property string pendingAction: ""
    property string errorText: ""
    property string statusText: ""

    // Every action shares the lock entry's footprint, so the row stays a
    // compact cluster instead of a list. The surface supplies the baseline
    // margin, which is what puts the row on the lock glyph's horizontal line.
    readonly property int buttonWidth: 68
    readonly property int buttonHeight: 48
    readonly property int buttonSpacing: 10
    readonly property int buttonCount: 3
    readonly property int rowWidth: buttonCount * buttonWidth + (buttonCount - 1) * buttonSpacing
    readonly property color controlColor: root.themeColor("control",
        Lazer.LazerTheme.settingsControlSurface)
    readonly property color hoverColor: root.themeColor("hover", Lazer.LazerTheme.hoverFill)
    readonly property color activeColor: root.themeColor("active", Lazer.LazerTheme.activeFill)
    readonly property color dividerColor: root.themeColor("divider", Lazer.LazerTheme.divider)
    readonly property color focusColor: root.themeColor("focus", Lazer.LazerTheme.focusRing)
    readonly property color pinkColor: root.themeColor("pink", Lazer.LazerTheme.osuPink)
    readonly property color textColor: root.themeColor("sessionText",
        SurfaceLogic.readableThemeColor(Lazer.LazerTheme.accentColor, root.lightScheme))
    readonly property string statusMessage: Logic.statusMessage(root.pendingAction,
        root.errorText, root.statusText)

    // The host restores keyboard ownership after a button hands it back.
    signal keyboardReleased()
    // A focused button forwards keys it does not own so the password field
    // keeps receiving them.
    signal keyForwarded(int key, string text)

    implicitWidth: rowWidth
    implicitHeight: buttonHeight
    width: implicitWidth
    height: implicitHeight
    visible: root.entranceRevealed
    enabled: root.entranceRevealed

    // Read one role out of the lock-cycle snapshot; fall back to the live theme
    // singleton only when no snapshot was supplied.
    function themeColor(role, fallback): color {
        if (!root.lockTheme)
            return fallback
        const value = root.lockTheme[role]
        return value === undefined ? fallback : value
    }

    function actionAvailable(actionId): bool {
        return root.sessionService && root.sessionService.isAvailable
                ? root.sessionService.isAvailable(actionId) : false
    }

    function actionRunning(): bool {
        return root.sessionService ? root.sessionService.running === true : false
    }

    // First activation arms the confirmation, the second one runs the action.
    function activateAction(actionId): void {
        if (!root.sessionService)
            return
        if (!Logic.canTrigger(actionId, root.actionAvailable(actionId),
                              root.sessionService.running))
            return
        const decision = Logic.confirmationAction(root.pendingAction, actionId)
        if (decision === "pending")
            return
        if (decision === "confirm") {
            root.pendingAction = ""
            if (root.sessionService.execute(actionId))
                root.statusText = ""
            return
        }
        root.pendingAction = actionId
        root.statusText = ""
        root.errorText = ""
    }

    function handleEscape(): bool {
        if (Logic.escapeAction(root.pendingAction) !== "cancel-confirmation")
            return false
        root.pendingAction = ""
        root.statusText = ""
        return true
    }

    function syncServiceMessage(): void {
        if (!root.sessionService)
            return
        root.errorText = String(root.sessionService.errorText || "")
        root.statusText = root.errorText || String(root.sessionService.resultText || "")
    }

    onSessionServiceChanged: {
        serviceConnections.target = root.sessionService
        syncServiceMessage()
    }

    // Static children only: a Repeater delegate never reaches the screen from
    // inside a session-lock surface.
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: root.buttonSpacing

        LockActionButton {
            id: suspendButton
            width: root.buttonWidth
            height: root.buttonHeight
            actionId: "suspend"
            label: Logic.labelFor(actionId)
            iconSource: Qt.resolvedUrl("../lazerbar/icons/suspend.svg")
            barHost: root
            available: root.actionAvailable(actionId)
            confirmationPending: root.pendingAction === actionId
            running: root.actionRunning()
            onActivated: actionId => root.activateAction(actionId)
            onKeyboardReleased: root.keyboardReleased()
            onKeyForwarded: (key, text) => root.keyForwarded(key, text)
        }

        LockActionButton {
            id: shutdownButton
            width: root.buttonWidth
            height: root.buttonHeight
            actionId: "shutdown"
            label: Logic.labelFor(actionId)
            iconSource: Qt.resolvedUrl("../lazerbar/icons/power.svg")
            barHost: root
            available: root.actionAvailable(actionId)
            confirmationPending: root.pendingAction === actionId
            running: root.actionRunning()
            onActivated: actionId => root.activateAction(actionId)
            onKeyboardReleased: root.keyboardReleased()
            onKeyForwarded: (key, text) => root.keyForwarded(key, text)
        }

        LockActionButton {
            id: logoutButton
            width: root.buttonWidth
            height: root.buttonHeight
            actionId: "logout"
            label: Logic.labelFor(actionId)
            iconSource: Qt.resolvedUrl("../lazerbar/icons/logout.svg")
            barHost: root
            available: root.actionAvailable(actionId)
            confirmationPending: root.pendingAction === actionId
            running: root.actionRunning()
            onActivated: actionId => root.activateAction(actionId)
            onKeyboardReleased: root.keyboardReleased()
            onKeyForwarded: (key, text) => root.keyForwarded(key, text)
        }
    }

    // One status line explains the row: a failure, the armed confirmation, or
    // the last service message. It floats above the row instead of shifting it.
    Text {
        id: statusLine
        anchors.right: parent.right
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        width: parent.width
        text: root.statusMessage
        color: root.errorText ? root.pinkColor : root.textColor
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        opacity: text.length > 0 ? 1 : 0

        Behavior on opacity {
            enabled: !root.reducedMotion
            NumberAnimation {
                duration: Lazer.MotionTokens.fast
                easing.type: Easing.OutQuint
            }
        }
        Behavior on color {
            enabled: !root.reducedMotion
            ColorAnimation { duration: Lazer.MotionTokens.fast }
        }
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
}
