import QtQuick
import QtQuick.Effects
import "../../services" as Services

// Provide the active pink music entry with flash and tooltip timing state.
Item {
    id: root

    property bool enabled: true
    property bool isActive: false
    readonly property bool hovered: enabled && (hoverHandler.hovered || (testMode && forceHoverForTest))
    property bool isFlashing: false
    property url iconSource
    property string titleText: Services.Tr.q("sidebar.music")
    property string subtitleText: Services.Tr.q("sidebar.music.subtitle")
    property bool testMode: false
    property bool forceHoverForTest: false
    property bool keyboardPressed: false
    property bool tooltipRequested: false
    readonly property bool flashActive: flash.flashActive
    readonly property Item flashOverlayItem: flash.flashOverlayItem
    readonly property Animation flashAnimationItem: flash.flashAnimationItem

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
        flash.restart()
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
    ClickFlash {
        id: flash
        anchors.fill: parent
        z: 10
        radius: 6
    }
    Timer { id: tooltipDelay; interval: 200; onTriggered: if (root.hovered && !root.isActive) root.tooltipRequested = true }
    HoverHandler { id: hoverHandler; enabled: root.enabled }
    TapHandler { id: tapHandler; enabled: root.enabled; onTapped: root.activate() }
}
