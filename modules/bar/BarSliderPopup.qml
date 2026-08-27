import QtQuick
import "."
import "../lazerbar"

// Slider card for volume/brightness hover popups, reusing the settings
// panel's verified slider control inside the two-layer popup frame.
BarPopupFrame {
    id: root

    property real value: 0
    property bool showMute: false
    property bool muted: false

    signal valueModified(real value)
    signal muteToggled()

    readonly property int percentValue: Math.round(Math.max(0, Math.min(1, value)) * 100)

    // Title/icon are the frame's own properties; keep alias for host binding.
    // host passes title/iconSource directly to the frame.

    implicitWidth: 280
    // Explicit dims keep the hosting Loader from stretching the surface.
    width: implicitWidth
    // Header (48) + divider (1) + content (slider 40 + mute 26 + spacing/margins)
    height: implicitHeight
    extraText: (root.muted ? "\u2014" : root.percentValue) + "%"

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        // The settings panel owns the slider contract; map to percent steps.
        LazerSettingsSlider {
            id: slider

            width: parent.width
            from: 0
            to: 100
            stepSize: 5
            value: root.percentValue
            accessibleName: root.title
            enabled: !(root.showMute && root.muted)
            onValueModified: newValue => root.valueModified(newValue / 100)
        }

        // Mute toggle only appears where it is meaningful.
        Rectangle {
            visible: root.showMute
            width: 92
            height: 26
            radius: 5
            color: muteHover.hovered ? LazerTheme.settingsResetSurfaceHover
                                     : LazerTheme.settingsResetSurface

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 2
                    color: root.muted ? LazerTheme.osuPink : LazerTheme.osuGreen

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.muted ? "Muted" : "Sound on"
                    color: LazerTheme.textPrimary
                    font.pixelSize: 11
                }
            }

            HoverHandler {
                id: muteHover
            }

            TapHandler {
                onTapped: root.muteToggled()
            }
        }
    }
}
