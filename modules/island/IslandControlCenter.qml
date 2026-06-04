import QtQuick
import QtQuick.Controls
import "../../services" as Services

// Lightweight control center page for the shared bottom overlay panel.
Item {
    id: root

    // Stack compact cards so the page stays readable inside the bottom panel.
    Column {
        anchors.fill: parent
        spacing: 12

        // Summarize the active media session at the top of the page.
        Rectangle {
            width: parent.width
            height: 112
            radius: 20
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: Services.MediaControlService.title !== "" ? Services.MediaControlService.title : "暂无媒体播放"
                    color: Services.Color.mOnSurface
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: Services.MediaControlService.artist !== "" ? Services.MediaControlService.artist : "打开播放器后这里会显示当前内容"
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    width: parent.width
                }

                // Provide the core transport controls inline with the media summary.
                Row {
                    spacing: 10

                    Rectangle {
                        width: 72
                        height: 32
                        radius: 16
                        color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.08)
                        opacity: Services.MediaControlService.canGoPrevious ? 1 : 0.45

                        Text {
                            anchors.centerIn: parent
                            text: "上一首"
                            color: Services.Color.mOnSurface
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: Services.MediaControlService.canGoPrevious
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Services.MediaControlService.previous()
                        }
                    }

                    Rectangle {
                        width: 88
                        height: 32
                        radius: 16
                        color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.22)
                        opacity: Services.MediaControlService.canTogglePlayback ? 1 : 0.45

                        Text {
                            anchors.centerIn: parent
                            text: Services.MediaControlService.playbackState === "playing" ? "暂停" : "播放"
                            color: Services.Color.mPrimary
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: Services.MediaControlService.canTogglePlayback
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Services.MediaControlService.playPause()
                        }
                    }

                    Rectangle {
                        width: 72
                        height: 32
                        radius: 16
                        color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.08)
                        opacity: Services.MediaControlService.canGoNext ? 1 : 0.45

                        Text {
                            anchors.centerIn: parent
                            text: "下一首"
                            color: Services.Color.mOnSurface
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: Services.MediaControlService.canGoNext
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Services.MediaControlService.next()
                        }
                    }
                }
            }
        }

        // Expose volume and brightness as the main quick controls.
        Row {
            width: parent.width
            height: 150
            spacing: 12

            // Speaker volume card.
            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: 20
                color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
                border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "音量"
                        color: Services.Color.mOnSurface
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Text {
                        text: Services.VolumeService.sinkMuted ? "已静音" : (Math.round(Services.VolumeService.sinkVolume * 100) + "%")
                        color: Services.VolumeService.sinkMuted ? Services.Color.mError : Services.Color.mPrimary
                        font.pixelSize: 26
                        font.bold: true
                    }

                    Slider {
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: Services.VolumeService.sinkMuted ? 0 : Services.VolumeService.sinkVolume
                        onMoved: Services.VolumeService.setSinkVolume(value)
                    }

                    Rectangle {
                        width: 96
                        height: 30
                        radius: 15
                        color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: Services.VolumeService.sinkMuted ? "取消静音" : "静音"
                            color: Services.Color.mOnSurface
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.VolumeService.toggleSinkMute()
                        }
                    }
                }
            }

            // Screen brightness card.
            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                radius: 20
                color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
                border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "亮度"
                        color: Services.Color.mOnSurface
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Text {
                        text: Math.round(Services.BrightnessService.brightness * 100) + "%"
                        color: Services.Color.mPrimary
                        font.pixelSize: 26
                        font.bold: true
                    }

                    Slider {
                        from: 0.01
                        to: 1
                        stepSize: 0.01
                        value: Services.BrightnessService.brightness
                        onMoved: Services.BrightnessService.setBrightness(value)
                    }
                }
            }
        }

        // Surface a few shell state hints without turning this into a full settings page.
        Rectangle {
            width: parent.width
            height: 112
            radius: 20
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "当前状态"
                    color: Services.Color.mOnSurface
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "模糊：" + (Services.SettingsService.appearance.enableBlur ? "开启" : "关闭")
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 13
                }

                Text {
                    text: "通知免打扰：" + (Services.SettingsService.notifications.dnd ? "开启" : "关闭")
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 13
                }

                Text {
                    text: "栏高度：" + Services.SettingsService.bar.height + "px"
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 13
                }
            }
        }
    }
}
