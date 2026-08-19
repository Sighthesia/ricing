import QtQuick
import QtQuick.Effects

// Render one fixed music transport control with keyboard feedback.
Item {
    id: root
    property bool enabled: true
    property bool active: false
    property bool outlined: false
    property url iconSource
    property string accessibleName: ""
    readonly property bool hovered: enabled && hover.hovered
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation
    signal clicked

    implicitWidth: outlined ? 40 : 30
    implicitHeight: outlined ? 40 : 30
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName

    Keys.onReturnPressed: if (enabled) activate()
    Keys.onEnterPressed: if (enabled) activate()
    Keys.onSpacePressed: if (enabled) activate()

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
        root.clicked()
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.hovered ? "#16FFFFFF" : "transparent"
        border.width: root.outlined ? 2 : root.activeFocus ? 1 : 0
        border.color: root.active ? LazerTheme.musicGold : "white"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.color { ColorAnimation { duration: MotionTokens.medium } }
    }
    Image { id: mask; anchors.centerIn: parent; width: root.outlined ? 20 : 18; height: width; source: root.iconSource; visible: false }
    MultiEffect { anchors.fill: mask; source: mask; colorization: 1; colorizationColor: root.active ? LazerTheme.musicGold : "white"; Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.medium } } }

    // Confirm an accepted transport action without changing its hit target.
    Rectangle {
        id: flashOverlay
        z: 10
        anchors.fill: parent
        radius: width / 2
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

    HoverHandler { id: hover; enabled: root.enabled }
    TapHandler { enabled: root.enabled; onTapped: root.activate() }
}
