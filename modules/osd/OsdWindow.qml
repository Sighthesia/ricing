import Quickshell
import Quickshell.Wayland
import QtQuick
import "../common" as Common
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
        WlrLayershell.exclusiveZone: -1

        // OSD size
        implicitWidth: 200
        implicitHeight: 120
        visible: osdSurface.opacity > 0 || osdWindow.osdVisible

        // Position at top-left corner
        anchors {
            top: true
            left: true
        }

        // OSD state
        property bool osdVisible: false
        property string icon: ""
        property string valueText: ""
        property real progress: 0
        property string osdType: "" // "volume", "brightness", "media"

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? osdBlurRegion : null

        // Bind blur to the transient OSD card rather than the whole overlay surface.
        Region {
            id: osdBlurRegion

            item: osdWindow.osdVisible ? osdContainer.blurSourceItem : null
            radius: osdContainer.blurRadius
        }

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

        // OSD surface content.
        Common.PopupSurface {
            id: osdSurface

            anchors.fill: parent
            transformOrigin: Item.Center
            shown: osdWindow.osdVisible

            // OSD content container.
            Common.GlassCapsule {
                id: osdContainer
                anchors.centerIn: parent
                width: 180
                height: 100
                radius: height / 2
                surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
                outlineColor: Services.Color.mOutline
                borderWidth: 1

                // Stack icon, value, and progress inside the capsule.
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
                                NumberAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing }
                            }
                        }
                    }
                }
            }
        }
    }
}
