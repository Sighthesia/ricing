import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Large media player card for the overview control-center collage.
// Shows a "Now Playing" header, cover art placeholder, title/artist,
// progress bar with time labels, and compact playback controls.
// Uses a hero glass treatment with ambient gradient and layered depth.
Rectangle {
    id: root

    signal clicked()

    // Real metadata from MediaControlService; shows the active player.
    readonly property string displayTitle: Services.MediaControlService.hasMedia
        ? Services.MediaControlService.title : "\u6682\u65E0\u64AD\u653E"
    readonly property string displayArtist: Services.MediaControlService.hasMedia
        ? Services.MediaControlService.artist : "\u7B49\u5F85\u64AD\u653E\u5668\u8FDE\u63A5"
    readonly property string displayArtUrl: Services.MediaControlService.artUrl
    readonly property real liveProgress: Services.MediaControlService.progress
    readonly property string elapsedTime: root._formatTime(Services.MediaControlService.positionMs)
    readonly property string remainingTime: root._formatTime(Services.MediaControlService.lengthMs)
    readonly property bool hasMedia: Services.MediaControlService.hasMedia
    readonly property bool isPlaying: Services.MediaControlService.playbackState === "playing"
    // Badge with the live player count so multiple simultaneous players read at a glance.
    readonly property int playerCount: Services.MediaService.playerCount

    radius: 16
    color: mediaMouse.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.4)
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    Behavior on border.color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    // Ambient hero gradient overlay — soft primary tint that gives the
    // media card a warm, spectrum-like background without hiding content.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.07) }
            GradientStop { position: 0.4; color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.02) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Top-edge glass highlight: a thin bright strip suggesting light
    // catching the top edge of a layered glass surface.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    // "Now Playing" header pinned to the top-left.
    Services.FluidText {
        id: nowPlayingHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 14
        text: "\u6B63\u5728\u64AD\u653E"
        color: Services.Color.mPrimary
        basePixelSize: 10
        font.bold: true
        opacity: 0.8
    }

    // Cover art square with real artwork or music-note placeholder.
    Rectangle {
        id: coverArt
        anchors.top: nowPlayingHeader.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 14
        width: 72
        height: 72
        radius: 14
        color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.18)
        border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.35)
        border.width: 1
        clip: true

        // Soft ambient glow disc behind the cover art square.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 16
            height: parent.height + 16
            radius: width / 2
            z: -1
            color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
            opacity: 0.6
            visible: artworkSource.status === Image.Ready
        }

        Image {
            id: artworkSource

            anchors.fill: parent
            source: root.displayArtUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            visible: status === Image.Ready

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
            visible: artworkSource.status !== Image.Ready
        }
    }

    // Player-count badge pinned beside the header when multiple players are live.
    Rectangle {
        visible: root.playerCount > 1
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 14
        width: 24
        height: 16
        radius: 8
        color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.22)
        border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.7)
        border.width: 1

        Services.FluidText {
            anchors.centerIn: parent
            text: String(root.playerCount)
            color: Services.Color.mPrimary
            basePixelSize: 9
            font.bold: true
        }
    }

    // Title and artist stacked beside the cover art.
    Column {
        anchors.left: coverArt.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: coverArt.verticalCenter
        spacing: 4

        Services.FluidText {
            width: parent.width
            text: root.displayTitle
            color: Services.Color.mOnSurface
            basePixelSize: 14
            font.bold: true
            elide: Text.ElideRight
        }

        Services.FluidText {
            width: parent.width
            text: root.displayArtist
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 11
            elide: Text.ElideRight
        }
    }

    // Progress bar track with time labels (elapsed / remaining).
    Item {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: coverArt.bottom
        anchors.topMargin: 12
        height: 18

        // Bar track.
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.12)

            // Filled portion tracks live playback progress.
            Rectangle {
                width: parent.width * root.liveProgress
                height: parent.height
                radius: 2
                color: Services.Color.mPrimary

                Behavior on width {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }
            }
        }

        // Live time labels: elapsed / total duration.
        Row {
            anchors.bottom: parent.bottom
            width: parent.width

            Services.FluidText {
                id: leftTime

                text: root.elapsedTime
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 9
            }

            Item {
                width: parent.width - leftTime.implicitWidth - rightTime.implicitWidth
                height: 1
            }

            Services.FluidText {
                id: rightTime

                text: root.remainingTime
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 9
            }
        }
    }

    // Live playback controls: previous, play/pause, next.
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 22

        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u23EE"
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 14
            opacity: Services.MediaControlService.canGoPrevious ? 0.9 : 0.3

            MouseArea {
                anchors.fill: parent
                cursorShape: Services.MediaControlService.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: Services.MediaControlService.canGoPrevious
                onClicked: Services.MediaControlService.previous()
            }
        }

        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.isPlaying ? "\u23F8" : "\u25B6"
            color: Services.Color.mOnSurface
            basePixelSize: 20
            opacity: Services.MediaControlService.canTogglePlayback ? 1 : 0.4

            MouseArea {
                anchors.fill: parent
                cursorShape: Services.MediaControlService.canTogglePlayback ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: Services.MediaControlService.canTogglePlayback
                onClicked: Services.MediaControlService.playPause()
            }
        }

        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u23ED"
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 14
            opacity: Services.MediaControlService.canGoNext ? 0.9 : 0.3

            MouseArea {
                anchors.fill: parent
                cursorShape: Services.MediaControlService.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: Services.MediaControlService.canGoNext
                onClicked: Services.MediaControlService.next()
            }
        }
    }

    MouseArea {
        id: mediaMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
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
