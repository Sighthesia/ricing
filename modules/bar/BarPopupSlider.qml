import QtQuick
import "../lazerbar"

// Shared slider/mute operation surface with settings control patterns.
Item {
    id: root

    property real value: 0.5
    property bool muted: false
    property string label: ""
    property bool showMute: true

    // Qt forbids a property `value` and a signal `valueChanged(real)` on the
    // same object (duplicate notify). The spec's `valueChanged(real)` is the
    // user-commit signal; we expose it as `valueCommitted` to keep the
    // component compilable. Hosts handle `onValueCommitted` instead of
    // `onValueChanged`; the property's implicit `valueChanged` remains for
    // binding observation.
    signal valueCommitted(real value)
    signal toggleRequested()

    implicitWidth: 240
    implicitHeight: 56
    width: implicitWidth
    height: implicitHeight

    readonly property real clampedValue: Math.max(0, Math.min(1, Number(root.value) || 0))
    readonly property bool effectiveMuted: !!root.muted

    // Hover state for mute button feedback.
    property bool muteHovered: false
    property bool mutePressed: false

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 8

        // Label row with muted hint.
        Text {
            id: labelText
            objectName: "sliderLabel"
            width: root.showMute ? parent.width - muteButton.width - 8 : parent.width
            text: root.label
            color: root.effectiveMuted ? LazerTheme.textMuted : LazerTheme.textPrimary
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
            visible: root.label !== ""
            opacity: root.effectiveMuted ? 0.6 : 1

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Row {
            id: controlRow
            width: parent.width
            height: 28
            spacing: 8

            // Slider track area.
            Item {
                id: trackHost
                objectName: "sliderTrackHost"
                width: root.showMute ? parent.width - muteButton.width - controlRow.spacing : parent.width
                height: parent.height
                clip: false

                Rectangle {
                    id: trackRect
                    objectName: "sliderTrack"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 6
                    radius: 3
                    color: LazerTheme.settingsTrack

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Rectangle {
                    id: fillRect
                    objectName: "sliderFill"
                    anchors.left: trackRect.left
                    anchors.verticalCenter: trackRect.verticalCenter
                    height: trackRect.height
                    radius: trackRect.radius
                    width: Math.max(0, trackRect.width * root.clampedValue)
                    color: root.effectiveMuted ? Qt.rgba(LazerTheme.accentColor.r, LazerTheme.accentColor.g, LazerTheme.accentColor.b, 0.35) : LazerTheme.accentColor
                    clip: true

                    Behavior on width {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
                    }
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Thumb.
                Rectangle {
                    id: thumb
                    objectName: "sliderThumb"
                    width: 10
                    height: 14
                    radius: 5
                    anchors.verticalCenter: trackRect.verticalCenter
                    x: Math.max(0, Math.min(trackRect.width - width, trackRect.width * root.clampedValue - width / 2))
                    color: LazerTheme.settingsSliderThumb
                    scale: dragHandler.active ? MotionTokens.pressScale : 1

                    Behavior on x {
                        enabled: !dragHandler.active && !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.sliderNubMove; easing.type: Easing.OutQuint }
                    }
                    Behavior on scale {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                    }
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Flash overlay for click feedback.
                Rectangle {
                    id: flashOverlay
                    anchors.fill: fillRect
                    radius: fillRect.radius
                    color: LazerTheme.textPrimary
                    opacity: 0
                }

                NumberAnimation {
                    id: flashAnimation
                    target: flashOverlay
                    property: "opacity"
                    from: MotionTokens.clickFlashOpacity
                    to: 0
                    duration: MotionTokens.clickFlashDuration
                    easing.type: MotionTokens.clickFlashEasing
                }

                HoverHandler {
                    id: sliderHover
                    enabled: true
                }

                TapHandler {
                    id: trackTap
                    objectName: "sliderTrackTap"
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: function(eventPoint) {
                        var pos = eventPoint.position.x
                        var frac = Math.max(0, Math.min(1, pos / trackRect.width))
                        root.valueCommitted(frac)
                        flashAnimation.restart()
                    }
                }

                DragHandler {
                    id: dragHandler
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: {
                        if (active) {
                            var startX = centroid.pressPosition.x
                            var frac = Math.max(0, Math.min(1, startX / trackRect.width))
                            root.valueCommitted(frac)
                        }
                    }
                    onTranslationChanged: {
                        if (active) {
                            var curX = centroid.pressPosition.x + translation.x
                            var frac2 = Math.max(0, Math.min(1, curX / trackRect.width))
                            root.valueCommitted(frac2)
                        }
                    }
                }
            }

            // Mute toggle button with hover/press feedback. Hidden for brightness.
            Rectangle {
                id: muteButton
                objectName: "sliderMuteButton"
                width: 32
                height: 28
                radius: 6
                visible: root.showMute
                enabled: root.showMute
                color: root.mutePressed ? LazerTheme.pressedFill : root.muteHovered ? LazerTheme.hoverFill : "transparent"
                border.width: 0

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                Text {
                    anchors.centerIn: parent
                    text: root.effectiveMuted ? "M" : "U"
                    color: root.effectiveMuted ? LazerTheme.textMuted : LazerTheme.textPrimary
                    font.pixelSize: 11
                    font.bold: true
                }

                HoverHandler {
                    id: muteHover
                    onHoveredChanged: root.muteHovered = hovered
                }

                TapHandler {
                    id: muteTap
                    objectName: "sliderMuteTap"
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onPressedChanged: root.mutePressed = pressed
                    onTapped: root.toggleRequested()
                }
            }
        }
    }
}
