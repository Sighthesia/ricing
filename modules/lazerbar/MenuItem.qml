import QtQuick

// Present one keyboard-accessible menu action.
Rectangle {
    id: root
    property string label: ""
    property string shortcut: ""
    property bool enabled: true
    property bool current: false
    signal triggered
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation

    implicitWidth: 220
    implicitHeight: 36
    radius: 7
    color: current ? "#18FFFFFF" : "transparent"
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: enabled

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        Text { width: parent.width - shortcutText.width - 12; anchors.verticalCenter: parent.verticalCenter; text: root.label; color: LazerTheme.textPrimary; elide: Text.ElideRight }
        Text { id: shortcutText; anchors.verticalCenter: parent.verticalCenter; text: root.shortcut; color: root.current ? LazerTheme.textMuted : "#85818A"; font.pixelSize: 11 }
    }
    function restartFlash() {
        if (!root.enabled || MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    function activate() {
        if (!root.enabled)
            return
        root.restartFlash()
        root.triggered()
    }

    Keys.onReturnPressed: root.activate()
    Keys.onEnterPressed: root.activate()
    Keys.onSpacePressed: root.activate()

    // Confirm an accepted menu action without changing the row's hit target.
    Rectangle {
        id: flashOverlay
        z: 10
        anchors.fill: parent
        radius: root.radius
        color: "white"
        opacity: 0
        enabled: false
    }

    NumberAnimation {
        id: flashAnimation
        target: flashOverlay
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
        running: false
    }

    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion)
                root.restartFlash()
        }
    }

    TapHandler { enabled: root.enabled; onTapped: root.activate() }
    HoverHandler { id: hover; enabled: root.enabled; onHoveredChanged: if (hovered) root.forceActiveFocus() }
    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
}
