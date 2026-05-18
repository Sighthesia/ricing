import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services

// OSD popup for volume/brightness/media feedback, centered on screen.
Variants {
    id: root

    model: Quickshell.screens

    // Per-screen OSD overlay
    PanelWindow {
        id: osdWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Center on screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        implicitWidth: 200
        implicitHeight: 120

        // OSD state
        property bool osdVisible: false
        property string icon: ""
        property string valueText: ""
        property real progress: 0
        property string osdType: "" // "volume", "brightness", "media"

        // Auto-hide timer
        Timer {
            id: hideTimer
            interval: 1500
            onTriggered: osdWindow.osdVisible = false
        }

        // Monitor service changes
        Connections {
            target: Services.VolumeService
            function onSinkVolumeChanged() {
                osdWindow.showOsd("volume",
                    Services.VolumeService.sinkMuted ? "🔇" : "🔊",
                    Math.round(Services.VolumeService.sinkVolume * 100) + "%",
                    Services.VolumeService.sinkVolume)
            }
            function onSinkMutedChanged() {
                osdWindow.showOsd("volume",
                    Services.VolumeService.sinkMuted ? "🔇" : "🔊",
                    Services.VolumeService.sinkMuted ? "静音" : Math.round(Services.VolumeService.sinkVolume * 100) + "%",
                    Services.VolumeService.sinkMuted ? 0 : Services.VolumeService.sinkVolume)
            }
        }

        Connections {
            target: Services.BrightnessService
            function onBrightnessChanged() {
                osdWindow.showOsd("brightness",
                    "☀",
                    Math.round(Services.BrightnessService.brightness * 100) + "%",
                    Services.BrightnessService.brightness)
            }
        }

        Connections {
            target: Services.MediaService
            function onPlayingChanged() {
                if (Services.MediaService.title) {
                    osdWindow.showOsd("media",
                        Services.MediaService.playing ? "▶" : "⏸",
                        Services.MediaService.title,
                        Services.MediaService.playing ? 1 : 0)
                }
            }
        }

        function showOsd(type, icon, value, progress) {
            osdWindow.osdType = type
            osdWindow.icon = icon
            osdWindow.valueText = value
            osdWindow.progress = progress
            osdWindow.osdVisible = true
            hideTimer.restart()
        }

        // OSD content container
        Rectangle {
            id: osdContainer
            anchors.centerIn: parent
            width: 180
            height: 100
            radius: 16
            color: Services.Color.mSurface
            border.color: Services.Color.mOutline
            border.width: 1
            opacity: osdWindow.osdVisible ? 1 : 0

            // Fade animation
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12

                // Icon and value row
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    // Icon
                    Text {
                        text: osdWindow.icon
                        font.pixelSize: 28
                        color: Services.Color.mOnSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Value
                    Text {
                        text: osdWindow.valueText
                        font.pixelSize: 18
                        font.bold: true
                        color: Services.Color.mOnSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Progress bar
                Rectangle {
                    width: 140
                    height: 6
                    radius: 3
                    color: Services.Color.mSurfaceVariant

                    Rectangle {
                        width: parent.width * osdWindow.progress
                        height: parent.height
                        radius: 3
                        color: Services.Color.mPrimary

                        // Smooth progress animation
                        Behavior on width {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }
            }
        }
    }
}
