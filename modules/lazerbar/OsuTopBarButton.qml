import QtQuick
import QtQuick.Effects

// Provide the active pink music entry with flash and tooltip timing state.
Item {
    id: root

    property bool enabled: true
    property bool isActive: false
    readonly property bool hovered: enabled && (hoverHandler.hovered || (testMode && forceHoverForTest))
    property bool isFlashing: false
    property url iconSource
    property string titleText: "Music player"
    property string subtitleText: "Playback controls"
    property bool testMode: false
    property bool forceHoverForTest: false
    property bool keyboardPressed: false
    property bool tooltipRequested: false
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation

    readonly property color backgroundColor: isActive ? LazerTheme.osuButtonActive
                                                      : hovered ? LazerTheme.osuButtonHover : "transparent"
    readonly property real iconOpacity: enabled ? (isActive || hovered ? 1 : 0.8)
                                                : MotionTokens.disabledOpacity
    readonly property real effectiveScale: MotionTokens.reducedMotion ? 1
                                                                      : keyboardPressed || tapHandler.pressed
                                                                        ? MotionTokens.pressScale
                                                                        : hovered ? MotionTokens.hoverScale : 1

    signal clicked

    implicitWidth: LazerTheme.targetSize
    implicitHeight: LazerTheme.targetSize
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: titleText

    // Flash with the shared click-flash contract used across the project.
    function restartFlash() {
        if (!root.enabled || MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }
    function activate() {
        if (!enabled) return
        restartFlash()
        clicked()
    }

    onHoveredChanged: {
        if (hovered && !isActive) tooltipDelay.restart()
        else {
            tooltipDelay.stop()
            tooltipRequested = false
        }
    }
    onIsActiveChanged: if (isActive) { tooltipDelay.stop(); tooltipRequested = false }

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.effectiveScale
        yScale: root.effectiveScale
        Behavior on xScale { NumberAnimation { duration: root.keyboardPressed || tapHandler.pressed ? MotionTokens.instant : MotionTokens.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
        Behavior on yScale { NumberAnimation { duration: root.keyboardPressed || tapHandler.pressed ? MotionTokens.instant : MotionTokens.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft } }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            keyboardPressed = true
            event.accepted = true
        }
    }
    Keys.onReleased: event => {
        if (keyboardPressed && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            keyboardPressed = false
            activate()
            event.accepted = true
        }
    }

    // Paint the button's persistent state surface.
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.backgroundColor
        border.width: root.activeFocus ? 1 : 0
        border.color: LazerTheme.focusRing
        Behavior on color { ColorAnimation { duration: root.isActive ? MotionTokens.medium : MotionTokens.fast } }
    }

    Image {
        id: iconMask
        anchors.centerIn: parent
        width: LazerTheme.iconSize
        height: LazerTheme.iconSize
        source: root.iconSource
        visible: false
    }
    MultiEffect {
        anchors.fill: iconMask
        source: iconMask
        colorization: 1
        colorizationColor: "white"
        opacity: root.iconOpacity
        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Flash above all button content without replacing the button.
    Rectangle {
        id: flashOverlay
        anchors.fill: parent
        z: 10
        radius: 6
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
    Timer { id: tooltipDelay; interval: 200; onTriggered: if (root.hovered && !root.isActive) root.tooltipRequested = true }
    HoverHandler { id: hoverHandler; enabled: root.enabled }
    TapHandler { id: tapHandler; enabled: root.enabled; onTapped: root.activate() }
}
