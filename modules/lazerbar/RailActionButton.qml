import QtQuick
import QtQuick.Effects

// The one rail action button: a full-width 40px slot carrying a compact hover
// surface, a click-flash overlay and a centered 20px icon. Used by the settings
// rail's back and collapse actions and by the launcher rail's collapse action.
//
// WHY THIS EXISTS: the launcher rail grew its own copy of this button and the
// two drifted apart in every dimension at once - 26px against 40px, inset 10px
// against full width, radius 4 against 12, a 16px icon against 20px. Two hand
// copies of one control is the defect; sharing the component is the fix, so the
// next adjustment lands on both rails or on neither.
//
// The activation area stays full width while the visual surface is inset, which
// is the settings panel's contract: pointer target and painted highlight are
// deliberately not the same rectangle.
Item {
    id: root

    // --- Host contract ----------------------------------------------------

    property string iconSource: ""
    property string accessibleName: ""
    // False disables pointer, keyboard and the click flash together.
    property bool interactive: true
    // Corner radius of the painted surface and of the flash that fills it.
    property int surfaceRadius: 12

    signal activated

    // --- Visual subtree, exposed for probes and tests ---------------------

    readonly property alias surfaceItem: actionSurface
    readonly property alias iconItem: actionIcon
    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation

    enabled: root.interactive
    activeFocusOnTab: root.interactive
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName

    scale: actionPress.pressed ? MotionTokens.pressScale : 1
    Behavior on scale { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast } }

    // Hover and flash both live on ONE surface rectangle, so the highlight and
    // the click confirmation can never describe two different shapes.
    Rectangle {
        id: actionSurface
        anchors.fill: parent
        radius: root.surfaceRadius
        color: actionHover.hovered ? LazerTheme.settingsRowHover : "transparent"
        border.width: 0
        border.color: "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Confirm the action without changing its input boundary.
    Rectangle {
        id: flashOverlay
        z: 1
        anchors.fill: actionSurface
        radius: actionSurface.radius
        color: LazerTheme.textPrimary
        opacity: 0
        enabled: false
    }

    // Icon centered in the painted surface, at the settings rail's 20px size.
    Image {
        id: actionIcon
        anchors.centerIn: actionSurface
        width: 20
        height: 20
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
    }
    MultiEffect {
        anchors.fill: actionIcon
        source: actionIcon
        visible: actionIcon.visible
        colorization: 1
        colorizationColor: actionHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
        Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
    }

    HoverHandler { id: actionHover; enabled: root.interactive }
    TapHandler {
        id: actionPress
        enabled: root.interactive
        onTapped: root.activate()
    }
    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate()
            event.accepted = true
        }
    }

    // No flash when it cannot be seen: reduced motion parks the overlay at zero
    // rather than leaving it wherever the last click reached.
    function restartFlash() {
        if (!root.interactive || MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    function activate() {
        if (!root.interactive)
            return
        root.forceActiveFocus()
        root.restartFlash()
        root.activated()
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
}
