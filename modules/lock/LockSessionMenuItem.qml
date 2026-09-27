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

    // Row colors come from the lock cycle snapshot so rows cannot drift while
    // the panel around them stays frozen.
    readonly property color activeColor: root.themeColor("active", Lazer.LazerTheme.activeFill)
    readonly property color hoverColor: root.themeColor("hover", Lazer.LazerTheme.hoverFill)
    readonly property color accentColor: root.themeColor("accent", Lazer.LazerTheme.accentColor)
    readonly property color pinkColor: root.themeColor("pink", Lazer.LazerTheme.osuPink)
    readonly property color labelColor: root.themeColor("label", Lazer.LazerTheme.textPrimary)
    readonly property color iconColor: root.themeColor("rowIcon", Lazer.LazerTheme.textMuted)
    readonly property color focusColor: root.themeColor("focus", Lazer.LazerTheme.focusRing)

    // Use color layers and a narrow bar for hover and confirmation states.
    Rectangle {
        id: surface
        anchors.fill: parent
        color: root.confirmationPending ? root.activeColor
                                        : hoverHandler.hovered
                                          ? root.hoverColor : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: root.focusColor

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
        color: root.confirmationPending ? root.pinkColor : root.accentColor
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
        color: root.confirmationPending ? root.pinkColor : root.iconColor
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
        color: root.labelColor
        font.pixelSize: 14
        elide: Text.ElideRight
    }

    Rectangle {
        id: flashOverlay
        z: 10
        anchors.fill: parent
        color: root.labelColor
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

    // Resolve one color role from the host's lock-cycle snapshot, falling back
    // to the live theme singleton when no snapshot exists (standalone use).
    function themeColor(role, fallback): color {
        const theme = root.menuHost ? root.menuHost.lockTheme : null
        if (!theme)
            return fallback
        const value = theme[role]
        return value === undefined ? fallback : value
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
