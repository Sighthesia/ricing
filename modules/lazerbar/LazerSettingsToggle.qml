import QtQuick

// Expose a keyboard and pointer friendly 44x20 settings capsule.
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property bool fillWidth: false
    readonly property string rowPresentation: "inline"
    signal toggled(bool checked)

    readonly property bool pressed: tapHandler.pressed
    readonly property bool focusVisible: activeFocus
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property Item nubItem: capsule
    readonly property bool nubMorphEnabled: false
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation

    implicitWidth: 44
    implicitHeight: 20
    width: Math.min(Math.max(0, isFinite(Number(requestedWidth)) ? Number(requestedWidth) : implicitWidth), effectiveAvailableWidth)
    height: implicitHeight
    Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
    opacity: effectiveEnabled ? 1 : MotionTokens.disabledOpacity
    activeFocusOnTab: effectiveEnabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled && activeFocus)
            focus = false
    }

    function activate() {
        if (!root.effectiveEnabled)
            return
        root.forceActiveFocus()
        root.toggled(!root.checked)
        root.restartFlash()
    }

    function restartFlash() {
        if (!root.effectiveEnabled || MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    Keys.onSpacePressed: event => { activate(); event.accepted = true }
    Keys.onReturnPressed: event => { activate(); event.accepted = true }

    // Paint the full capsule as the state indicator without a moving thumb.
    Rectangle {
        id: capsule
        anchors.fill: parent
        radius: 10
        color: root.checked ? LazerTheme.settingsAccent : LazerTheme.settingsToggleOff
        border.width: 1.5
        border.color: LazerTheme.settingsAccent
        scale: root.pressed ? MotionTokens.pressScale : 1

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
        Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
    }

    // Confirm an accepted toggle without changing the capsule's input boundary.
    Rectangle {
        id: flashOverlay
        z: 1
        anchors.fill: capsule
        radius: capsule.radius
        color: LazerTheme.textPrimary
        opacity: 0
        enabled: false
    }

    // Match the shared osu-style click flash timing.
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

    // Keep hover state local to the capsule so the parent row can observe it
    // without changing the toggle's input boundary.
    HoverHandler {
        id: hoverHandler
        enabled: root.effectiveEnabled
    }
    TapHandler {
        id: tapHandler
        enabled: root.effectiveEnabled
        onTapped: {
            root.activate()
        }
    }
}
