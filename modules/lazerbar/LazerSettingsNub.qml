import QtQuick

// Shared osu-style nub primitive for toggle and slider controls: a fixed
// 50x15 outline whose checked state is expressed through fill and border
// morph, and whose hover/drag state adds an accent glow.
Item {
    id: root

    property bool checked: false
    property bool sliderMode: false
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool enabled: true
    property color accent: LazerTheme.osuPink

    readonly property bool effectiveChecked: checked && !sliderMode
    readonly property real fillScale: effectiveChecked ? 1 : 0.75
    readonly property real fillOpacity: effectiveChecked ? 1 : 0
    readonly property real borderWidth: effectiveChecked ? LazerTheme.nubBorderChecked : LazerTheme.nubBorder
    readonly property bool glowVisible: glow.opacity > 0.01
    readonly property real glowScale: glow.scale
    readonly property bool morphBehaviorEnabled: fillBehavior.enabled
    readonly property bool glowBehaviorEnabled: glowScaleBehavior.enabled
    readonly property bool colorTransitionEnabled: colorBehavior.enabled

    implicitWidth: 50
    implicitHeight: 15
    width: 50
    height: 15
    opacity: enabled ? 1 : MotionTokens.disabledOpacity

    // Paint the accent glow behind the nub; it pops in fast on hover and
    // relaxes over 800ms when the pointer leaves, matching osu's nub.
    Rectangle {
        id: glow
        anchors.centerIn: parent
        width: parent.width + 16
        height: parent.height + 16
        radius: 10
        color: root.accent
        opacity: (root.hovered || root.pressed) && root.enabled ? LazerTheme.nubGlowOpacity : 0
        scale: (root.hovered || root.pressed) && root.enabled ? 1 : 0.6

        Behavior on opacity {
            id: glowOpacityBehavior
            enabled: !MotionTokens.reducedMotion
            NumberAnimation {
                duration: (root.hovered || root.pressed) ? MotionTokens.nubHover : MotionTokens.nubGlow
                easing.type: Easing.OutQuint
            }
        }
        Behavior on scale {
            id: glowScaleBehavior
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.nubGlow; easing.type: Easing.OutQuint }
        }
    }

    // Keep the fixed outlined body with a morphing border thickness.
    Rectangle {
        id: body
        anchors.fill: parent
        radius: 4
        color: "transparent"
        border.color: LazerTheme.textPrimary
        border.width: root.borderWidth

        Behavior on border.width {
            id: borderBehavior
            enabled: !MotionTokens.reducedMotion
            NumberAnimation {
                duration: MotionTokens.nubMorph
                easing.type: root.effectiveChecked ? Easing.OutElastic : Easing.OutQuint
                easing.amplitude: 1
                easing.period: 0.5
            }
        }
    }

    // Expand the accent fill from 75% width to full and fade it in when checked.
    Rectangle {
        id: fill
        anchors.centerIn: parent
        width: parent.width * root.fillScale
        height: parent.height
        radius: 4
        color: root.accent
        opacity: root.fillOpacity

        Behavior on width {
            id: fillBehavior
            enabled: !MotionTokens.reducedMotion
            NumberAnimation {
                duration: MotionTokens.nubMorph
                easing.type: root.effectiveChecked ? Easing.OutElastic : Easing.OutQuint
                easing.amplitude: 1
                easing.period: 0.5
            }
        }
        Behavior on opacity {
            id: fillOpacityBehavior
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.nubMorph; easing.type: Easing.OutQuint }
        }
    }

    // Colors always fade, even under reduced motion, to keep terminal states legible.
    Behavior on accent {
        id: colorBehavior
        ColorAnimation { duration: MotionTokens.nubGlow; easing.type: Easing.OutQuint }
    }
}