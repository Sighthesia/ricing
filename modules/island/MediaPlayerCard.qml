import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Single media player card for the control-center media detail page.
// Shows cover art, title/artist, progress bar with time labels, and
// compact playback controls. Clicking the card selects this player as
// the active media source.
Rectangle {
    id: root

    // The MPRIS player backing this card. Pass the live player object
    // from the MediaService.playerList model.
    property var player: null
    property bool isActive: false

    signal clicked()

    readonly property string _playerKey: root.player ? (root.player.identity || root.player.desktopEntry || "") : ""
    readonly property string _title: root.player ? (root.player.trackTitle || "") : ""
    readonly property string _artist: root.player ? (root.player.trackArtist || "") : ""
    readonly property string _artUrl: root.player ? (root.player.trackArtUrl || "") : ""
    readonly property string _playbackState: {
        if (!root.player)
            return "stopped"
        if (root.player.playbackState === MprisPlaybackState.Playing)
            return "playing"
        if (root.player.playbackState === MprisPlaybackState.Paused)
            return "paused"
        return "stopped"
    }
    readonly property bool _isPlaying: root._playbackState === "playing"
    readonly property bool _canGoPrevious: root.player && root.player.canControl && root.player.canGoPrevious
    readonly property bool _canTogglePlayback: root.player && root.player.canControl && root.player.canTogglePlaying
    readonly property bool _canGoNext: root.player && root.player.canControl && root.player.canGoNext
    readonly property int _positionMs: {
        if (!root.player || !root.player.positionSupported)
            return 0
        return Math.max(0, Math.round(root.player.position * 1000))
    }
    readonly property int _lengthMs: root.player && root.player.lengthSupported
        ? Math.max(0, Math.round(root.player.length * 1000))
        : 0
    readonly property real _progress: root._lengthMs > 0
        ? Math.max(0, Math.min(1, root._positionMs / root._lengthMs))
        : 0
    readonly property bool _artworkReady: artworkSource.status === Image.Ready
    readonly property color _artFallbackColor: Qt.rgba(
        Services.Color.mSurfaceVariant.r,
        Services.Color.mSurfaceVariant.g,
        Services.Color.mSurfaceVariant.b,
        0.9
    )

    implicitHeight: 140
    radius: 14
    color: cardMouse.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
    border.color: root.isActive
        ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.7)
        : Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.4)
    border.width: root.isActive ? 2 : 1

    Behavior on color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    Behavior on border.color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    // Ambient hero gradient overlay for the active card.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: root.isActive
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.07) }
            GradientStop { position: 0.4; color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.02) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Top-edge glass highlight strip.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    Row {
        id: cardContent

        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Cover art square with soft ambient glow.
        Rectangle {
            id: coverArt

            anchors.verticalCenter: parent.verticalCenter
            width: 72
            height: 72
            radius: 14
            color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.18)
            border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.35)
            border.width: 1
            clip: true

            // Soft ambient glow disc behind the cover art.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 16
                height: parent.height + 16
                radius: width / 2
                z: -1
                color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
                opacity: 0.6
                visible: root._artworkReady
            }

            Image {
                id: artworkSource

                anchors.fill: parent
                source: root._artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: root._artworkReady

                onStatusChanged: {
                    if (status === Image.Error && source !== "")
                        Services.MediaService.reportArtLoadFailure(source)
                }
            }

            Services.FluidText {
                anchors.centerIn: parent
                text: "\u266A"
                color: Services.Color.mPrimary
                basePixelSize: 28
                visible: !root._artworkReady
            }
        }

        // Title/artist + progress + controls column.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: cardContent.width - coverArt.width - cardContent.spacing
            spacing: 6

            // Player name header with active indicator.
            Row {
                spacing: 6

                Services.FluidText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._playerKey
                    color: Services.Color.mPrimary
                    basePixelSize: 10
                    font.bold: true
                    opacity: 0.8
                    elide: Text.ElideRight
                }

                // Active badge.
                Rectangle {
                    visible: root.isActive
                    width: 28
                    height: 14
                    radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.22)
                    border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.7)
                    border.width: 1

                    Services.FluidText {
                        anchors.centerIn: parent
                        text: "\u5F53\u524D"
                        color: Services.Color.mPrimary
                        basePixelSize: 8
                        font.bold: true
                    }
                }
            }

            Services.FluidText {
                width: parent.width
                text: root._title !== "" ? root._title : "\u6682\u65E0\u66F2\u76EE"
                color: Services.Color.mOnSurface
                basePixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            Services.FluidText {
                width: parent.width
                text: root._artist !== "" ? root._artist : "\u672A\u77E5\u827A\u672F\u5BB6"
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 11
                elide: Text.ElideRight
            }

            // Progress bar track with time labels.
            Item {
                width: parent.width
                height: 18

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.12)

                    Rectangle {
                        width: parent.width * root._progress
                        height: parent.height
                        radius: 2
                        color: Services.Color.mPrimary
                    }
                }

                Row {
                    anchors.bottom: parent.bottom
                    width: parent.width

                    Services.FluidText {
                        id: leftTime

                        text: root._formatTime(root._positionMs)
                        color: Services.Color.mOnSurfaceVariant
                        basePixelSize: 9
                    }

                    Item {
                        width: parent.width - leftTime.implicitWidth - rightTime.implicitWidth
                        height: 1
                    }

                    Services.FluidText {
                        id: rightTime

                        text: root._formatTime(root._lengthMs)
                        color: Services.Color.mOnSurfaceVariant
                        basePixelSize: 9
                    }
                }
            }

            // Compact playback controls.
            Row {
                spacing: 16

                IslandActionButton {
                    text: "\u4E0A\u4E00\u9996"
                    enabled: root._canGoPrevious
                    onClicked: {
                        if (root.player && root._canGoPrevious)
                            root.player.previous()
                    }
                }

                IslandActionButton {
                    text: root._isPlaying ? "\u6682\u505C" : "\u64AD\u653E"
                    enabled: root._canTogglePlayback
                    onClicked: {
                        if (!root.player || !root._canTogglePlayback)
                            return
                        if (root._isPlaying)
                            root.player.pause()
                        else
                            root.player.play()
                    }
                }

                IslandActionButton {
                    text: "\u4E0B\u4E00\u9996"
                    enabled: root._canGoNext
                    onClicked: {
                        if (root.player && root._canGoNext)
                            root.player.next()
                    }
                }
            }
        }
    }

    MouseArea {
        id: cardMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root._playerKey !== "")
                Services.MediaService.setActivePlayer(root._playerKey)
            root.clicked()
        }
    }

    function _formatTime(ms) {
        if (!ms || ms <= 0)
            return "0:00"
        const totalSeconds = Math.floor(ms / 1000)
        const minutes = Math.floor(totalSeconds / 60)
        const seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" + seconds : "" + seconds)
    }
}
