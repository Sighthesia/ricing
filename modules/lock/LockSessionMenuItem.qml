import QtQuick
import "../lazerbar" as Lazer

// Render one sharp, keyboard-accessible session action row.
Item {
    id: root

    property string actionId: ""
    property string label: ""
    property string iconSource: ""
    property var menuHost: null
    property bool available: true
    property bool confirmationPending: false
    property bool running: false
    readonly property bool interactive: root.available && !root.running

    signal activated(string actionId)

    implicitWidth: 292
    implicitHeight: 44
    width: implicitWidth
    height: implicitHeight
    enabled: interactive
    opacity: available ? 1 : Lazer.MotionTokens.disabledOpacity
    activeFocusOnTab: interactive

    // Use color layers and a narrow bar for hover and confirmation states.
    Rectangle {
        id: surface
        anchors.fill: parent
        color: root.confirmationPending ? Lazer.LazerTheme.activeFill
                                        : hoverHandler.hovered
                                          ? Lazer.LazerTheme.hoverFill : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: Lazer.LazerTheme.focusRing

        Behavior on color {
            enabled: !Lazer.MotionTokens.reducedMotion
            ColorAnimation { duration: Lazer.MotionTokens.fast }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        color: root.confirmationPending ? Lazer.LazerTheme.osuPink
                                        : Lazer.LazerTheme.accentColor
        opacity: root.confirmationPending || hoverHandler.hovered || root.activeFocus ? 1 : 0
        Behavior on opacity {
            enabled: !Lazer.MotionTokens.reducedMotion
            NumberAnimation { duration: Lazer.MotionTokens.fast; easing.type: Easing.OutQuint }
        }
    }

    // Keep the icon slot stable even when an action is unavailable.
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        text: root.iconSource
        color: root.confirmationPending ? Lazer.LazerTheme.osuPink : Lazer.LazerTheme.textMuted
        font.pixelSize: 12
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 48
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.confirmationPending ? "Confirm " + root.label + "?" : root.label
        color: Lazer.LazerTheme.textPrimary
        font.pixelSize: 14
        elide: Text.ElideRight
    }

    Rectangle {
        id: flashOverlay
        z: 10
        anchors.fill: parent
        color: Lazer.LazerTheme.textPrimary
        opacity: 0
        enabled: false
    }

    NumberAnimation {
        id: flashAnimation
        target: flashOverlay
        property: "opacity"
        from: Lazer.MotionTokens.clickFlashOpacity
        to: 0
        duration: Lazer.MotionTokens.clickFlashDuration
        easing.type: Lazer.MotionTokens.clickFlashEasing
        running: false
    }

    function activate(): void {
        if (!root.interactive)
            return
        if (!Lazer.MotionTokens.reducedMotion)
            flashAnimation.restart()
        else
            flashOverlay.opacity = 0
        root.activated(root.actionId)
    }

    Keys.onReturnPressed: root.activate()
    Keys.onEnterPressed: root.activate()
    Keys.onSpacePressed: root.activate()
    Keys.onEscapePressed: event => {
        event.accepted = root.menuHost ? root.menuHost.handleEscape() : false
    }

    TapHandler {
        enabled: root.interactive
        onTapped: root.activate()
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        onHoveredChanged: if (hovered) root.forceActiveFocus()
    }
}
