import QtQuick
import "../lazerbar"
import "../../../services" as Services

// Slider card for volume/brightness hover popups, reusing the settings
// panel's verified slider control inside a sharp popup surface.
Rectangle {
    id: root

    property string title: ""
    property string iconSource: ""
    property real value: 0
    property bool showMute: false
    property bool muted: false

    signal valueModified(real value)
    signal muteToggled()

    readonly property int percentValue: Math.round(Math.max(0, Math.min(1, value)) * 100)

    implicitWidth: 280
    implicitHeight: 104
    radius: 10
    color: LazerTheme.popupBackground
    border.width: 1
    border.color: LazerTheme.popupBorder

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Row {
            width: parent.width
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: root.iconSource
                opacity: 0.9
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - parent.spacing - 16 - percentText.width
                text: root.title
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                id: percentText

                anchors.verticalCenter: parent.verticalCenter
                text: (root.muted ? "\u2014" : root.percentValue) + "%"
                color: LazerTheme.textMuted
                font.pixelSize: 13
            }
        }

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
