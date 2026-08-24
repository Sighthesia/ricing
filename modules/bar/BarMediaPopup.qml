import QtQuick
import "../lazerbar"
import "../../services" as Services

// Transport card for the media hover popup: track identity, progress strip,
// and geometric transport controls.
Rectangle {
    id: root

    implicitWidth: 300
    implicitHeight: 148
    radius: 10
    color: LazerTheme.popupBackground
    border.width: 1
    border.color: LazerTheme.popupBorder

    readonly property real progressFraction:
        Services.MediaService.lengthMs > 0
        ? Math.max(0, Math.min(1, Services.MediaService.positionMs / Services.MediaService.lengthMs))
        : 0

    function formatTime(ms) {
        if (!(ms > 0))
            return "0:00"
        var totalSeconds = Math.floor(ms / 1000)
        return Math.floor(totalSeconds / 60) + ":" + String(totalSeconds % 60).padStart(2, "0")
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            width: parent.width
            text: Services.MediaService.title || "Nothing playing"
            color: LazerTheme.textPrimary
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Services.MediaService.artist
            color: LazerTheme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
            visible: Services.MediaService.artist !== ""
        }

        // Progress strip mirrors the bar's level language.
        Item {
            id: progressHost

            width: parent.width
            height: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 3
                radius: 1.5
                color: LazerTheme.settingsTrack
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.progressFraction
                height: 3
                radius: 1.5
                color: LazerTheme.accentColor

                Behavior on width { NumberAnimation { duration: MotionTokens.fast } }
            }
        }

        // Time labels flank the progress host's full width.
        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                text: root.formatTime(Services.MediaService.positionMs)
                color: LazerTheme.textMuted
                font.pixelSize: 10
            }

            Text {
                anchors.right: parent.right
                text: root.formatTime(Services.MediaService.lengthMs)
                color: LazerTheme.textMuted
                font.pixelSize: 10
            }
        }

        // Transport row: previous / play-pause / next squares.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: [
                    {
                        glyph: "\u25C0",
                        action: function () { return Services.MediaService.previous() },
                        enabled: Services.MediaService.canGoPrevious,
                        accessibleName: "Previous",
                    },
                    {
                        glyph: Services.MediaService.playing ? "\u2016" : "\u25B6",
                        action: function () { return Services.MediaService.playPause() },
                        enabled: Services.MediaService.canTogglePlayback,
                        accessibleName: Services.MediaService.playing ? "Pause" : "Play",
                    },
                    {
                        glyph: "\u25B6",
                        action: function () { return Services.MediaService.next() },
                        enabled: Services.MediaService.canGoNext,
                        accessibleName: "Next",
                    },
                ]

                delegate: Rectangle {
                    id: transportButton

                    required property var modelData
                    required property int index

                    readonly property bool isPrimary: index === 1

                    width: isPrimary ? 44 : 34
                    height: 34
                    radius: 5
                    color: controlHover.hovered && transportButton.modelData.enabled
                           ? LazerTheme.settingsResetSurfaceHover : LazerTheme.settingsResetSurface
                    opacity: transportButton.modelData.enabled ? 1 : MotionTokens.disabledOpacity

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: transportButton.modelData.glyph
                        color: LazerTheme.textPrimary
                        font.pixelSize: 13
                    }

                    HoverHandler {
                        id: controlHover
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: if (transportButton.modelData.enabled)
                                      transportButton.modelData.action()
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: transportButton.modelData.accessibleName
                }
            }
        }
    }
}
