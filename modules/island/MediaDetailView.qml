import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Media detail page for the shared island surface.
Item {
    id: root

    Column {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            width: parent.width
            height: 110
            radius: 18
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                Services.FluidText {
                    text: Services.MediaControlService.title !== "" ? Services.MediaControlService.title : "暂无媒体"
                    color: Services.Color.mOnSurface
                    basePixelSize: 16
                    font.bold: true
                    width: parent.width
                    elide: Text.ElideRight
                }

                Services.FluidText {
                    text: Services.MediaControlService.artist !== "" ? Services.MediaControlService.artist : "等待播放器连接"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 12
                    width: parent.width
                    elide: Text.ElideRight
                }

                Services.FluidText {
                    text: Services.MediaControlService.playbackState
                    color: Services.Color.mPrimary
                    basePixelSize: 11
                    width: parent.width
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8

            IslandActionButton {
                text: "上一首"
                enabled: Services.MediaControlService.canGoPrevious
                onClicked: Services.MediaControlService.previous()
            }

            IslandActionButton {
                text: Services.MediaControlService.playbackState === "playing" ? "暂停" : "播放"
                enabled: Services.MediaControlService.canTogglePlayback
                onClicked: Services.MediaControlService.playPause()
            }

            IslandActionButton {
                text: "下一首"
                enabled: Services.MediaControlService.canGoNext
                onClicked: Services.MediaControlService.next()
            }
        }
    }
}
