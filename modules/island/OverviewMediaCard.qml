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

    // Fake presentation data; real progress sync is out of scope.
    readonly property string displayTitle: Services.MediaControlService.hasMedia
        ? Services.MediaControlService.title : "\u6682\u65E0\u64AD\u653E"
    readonly property string displayArtist: Services.MediaControlService.hasMedia
        ? Services.MediaControlService.artist : "\u7B49\u5F85\u64AD\u653E\u5668\u8FDE\u63A5"
    readonly property real fakeProgress: 0.42

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

    // Cover art placeholder: a large rounded square with a music note,
    // backed by a soft ambient glow for hero emphasis. The glow sits as a
    // child with z: -1 so it extends behind coverArt's background without
    // affecting the anchor relationships that other siblings depend on.
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

        // Soft ambient glow disc behind the cover art square; extends
        // beyond the parent boundaries (no clip on this Rectangle).
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 16
            height: parent.height + 16
            radius: width / 2
            z: -1
            color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
            opacity: 0.6
        }

        Services.FluidText {
            anchors.centerIn: parent
            text: "\u266A"
            color: Services.Color.mPrimary
            basePixelSize: 28
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

            // Filled portion.
            Rectangle {
                width: parent.width * root.fakeProgress
                height: parent.height
                radius: 2
                color: Services.Color.mPrimary
            }
        }

        // Time labels below the bar.
        Row {
            anchors.bottom: parent.bottom
            width: parent.width

            Services.FluidText {
                id: leftTime
                text: "1:23"
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 9
            }

            Item {
                width: parent.width - leftTime.implicitWidth - rightTime.implicitWidth
                height: 1
            }

            Services.FluidText {
                id: rightTime
                text: "3:45"
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 9
            }
        }
    }

    // Compact playback controls: previous, play/pause, next.
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
            opacity: 0.7
        }

        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25B6"
            color: Services.Color.mOnSurface
            basePixelSize: 20
        }

        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u23ED"
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 14
            opacity: 0.7
        }
    }

    MouseArea {
        id: mediaMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
