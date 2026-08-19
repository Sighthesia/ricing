import QtQuick
import QtQuick.Effects
import "LazerBarLogic.js" as Logic

// Provide one continuous icon button across every interaction state.
Item {
    id: root

    property bool enabled: true
    property url source
    property string accessibleName: ""
    property bool active: false
    property bool supportsHover: true
    property bool testMode: false
    property bool forceHoverForTest: false
    property bool forcePressForTest: false
    property color inactiveColor: LazerTheme.iconInactive
    property color activeColor: LazerTheme.osuGreen

    readonly property bool hovered: enabled && supportsHover
                                    && (hoverHandler.hovered || (testMode && forceHoverForTest))
    readonly property bool pressed: enabled
                                    && (tapHandler.pressed || keyboardPressed
                                        || (testMode && forcePressForTest))
    readonly property string buttonState: Logic.visualState(enabled, active, hovered, pressed)
    readonly property real effectiveScale: MotionTokens.reducedMotion ? 1
                                                                      : (pressed ? MotionTokens.pressScale
                                                                                 : hovered ? MotionTokens.hoverScale : 1)
    readonly property real effectiveYOffset: MotionTokens.reducedMotion ? 0
                                                                        : (pressed ? MotionTokens.buttonNudge : 0)
    readonly property color foregroundColor: active ? activeColor
                                                     : hovered ? LazerTheme.hoverForeground : inactiveColor
    readonly property color backgroundColor: pressed ? LazerTheme.pressedFill
                                                      : active ? LazerTheme.activeFill
                                                               : hovered ? LazerTheme.hoverFill : "transparent"
    readonly property int transformDuration: pressed ? MotionTokens.instant : MotionTokens.fast
    property bool keyboardPressed: false
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation

    signal clicked
    signal keyboardActivated

    implicitWidth: LazerTheme.targetSize
    implicitHeight: LazerTheme.targetSize
    opacity: enabled ? 1 : MotionTokens.disabledOpacity
    focus: false
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName

    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.effectiveScale
            yScale: root.effectiveScale

            Behavior on xScale {
                NumberAnimation { duration: root.transformDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft }
            }
            Behavior on yScale {
                NumberAnimation { duration: root.transformDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft }
            }
        },
        Translate {
            y: root.effectiveYOffset
            Behavior on y {
                NumberAnimation { duration: root.transformDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outSoft }
            }
        }
    ]

    Keys.onPressed: event => {
        if (!root.enabled || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter
                              && event.key !== Qt.Key_Space))
            return
        root.keyboardPressed = true
        event.accepted = true
    }

    Keys.onReleased: event => {
        if (!root.keyboardPressed || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter
                                      && event.key !== Qt.Key_Space))
            return
        root.keyboardPressed = false
        root.keyboardActivated()
        root.activate()
        event.accepted = true
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
        root.clicked()
    }

    // Paint the interactive button surface.
    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: root.backgroundColor
        border.width: root.activeFocus ? 1 : 0
        border.color: LazerTheme.focusRing

        Behavior on color {
            ColorAnimation { duration: root.active ? MotionTokens.medium : MotionTokens.fast }
        }
    }

    Image {
        id: iconSource
        anchors.centerIn: parent
        width: LazerTheme.iconSize
        height: LazerTheme.iconSize
        source: root.source
        visible: false
        fillMode: Image.PreserveAspectFit
    }

    MultiEffect {
        anchors.fill: iconSource
        source: iconSource
        colorization: 1
        colorizationColor: root.foregroundColor

        Behavior on colorizationColor {
            ColorAnimation { duration: root.active ? MotionTokens.medium : MotionTokens.fast }
        }
    }

    // Confirm an accepted icon action without changing its hit target.
    Rectangle {
        id: flashOverlay
        z: 10
        anchors.fill: parent
        radius: Math.min(width, height) / 2
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

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled && root.supportsHover
    }

    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: root.activate()
    }
}
