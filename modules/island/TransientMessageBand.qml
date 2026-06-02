import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects
import "../../services" as Services

// Adaptive transient message card shown beside the collapsed island clock.
// Top row: app/source icon + app name + title. Below: full notification body
// or an OSD progress bar / media artist. Sizes to its content (width and
// height) so the island springs open to fit it, and collapses to zero when
// idle. Reads TransientMessageService.current.
Item {
    id: root

    readonly property var msg: Services.TransientMessageService.current
    readonly property string kind: msg ? (msg.kind || "") : ""
    readonly property string glyph: msg ? (msg.glyph || "") : ""
    readonly property string rawIcon: msg ? (msg.icon || "") : ""
    readonly property string appName: msg ? (msg.appName || "") : ""
    readonly property string title: msg ? (msg.title || "") : ""
    readonly property string body: msg ? (msg.body || "") : ""
    readonly property real progress: msg ? (msg.progress ?? -1) : -1

    // Resolve the icon source: a file/url path is used directly, a bare
    // freedesktop icon name is routed through the icon theme, else empty.
    readonly property string iconSource: {
        if (rawIcon === "") return ""
        if (rawIcon.indexOf("/") !== -1 || rawIcon.indexOf(":") !== -1) return rawIcon
        return Quickshell.iconPath(rawIcon, true)
    }
    readonly property bool showArt: kind === "media" && rawIcon !== "" && artImage.status === Image.Ready
    readonly property bool showAppIcon: kind === "notification" && iconSource !== "" && appIcon.status === Image.Ready
    readonly property bool showGlyph: glyph !== "" && !showArt && !showAppIcon
    readonly property bool showFallbackBell: kind === "notification" && !showAppIcon && !showGlyph
    readonly property bool hasLeading: showArt || showAppIcon || showGlyph || showFallbackBell

    // Zero size when idle so the island returns to its bare clock size.
    implicitWidth: Services.TransientMessageService.active ? card.implicitWidth + 12 : 0
    implicitHeight: Services.TransientMessageService.active ? card.implicitHeight : 26
    clip: true
    visible: Services.TransientMessageService.active || implicitWidth > 1

    Behavior on implicitWidth {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }

    Column {
        id: card
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 4

        // Top row: leading separator, icon/art/glyph, app name + title.
        Row {
            id: headRow
            spacing: 6

            // Vertical separator distinguishing the message from the clock.
            Rectangle {
                width: 1
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Color.mOutline
            }

            // Leading indicator: media art, app icon, glyph, or bell fallback.
            Item {
                id: leadingSlot
                visible: root.hasLeading
                width: visible ? 18 : 0
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: artImage
                    anchors.fill: parent
                    visible: false
                    source: root.kind === "media" ? root.rawIcon : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                }

                Rectangle {
                    id: artMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: artImage
                    maskSource: artMask
                    visible: root.showArt
                }

                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: root.kind === "notification" ? root.iconSource : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 18
                    sourceSize.height: 18
                    asynchronous: true
                    visible: root.showAppIcon
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.showGlyph || root.showFallbackBell
                    text: root.showGlyph ? root.glyph : "\uf0f3"
                    font.family: root.showGlyph ? font.family : "Symbols Nerd Font"
                    font.pixelSize: 13
                    color: Services.Color.mOnSurface
                }
            }

            // App name (small) + title (bold), stacked tightly.
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    visible: root.appName !== ""
                    text: root.appName
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220)
                }

                Text {
                    text: root.title
                    color: Services.Color.mOnSurface
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220)
                }
            }
        }

        // Body text: full notification body, wrapped, indented under the head.
        Text {
            visible: root.body !== ""
            leftPadding: 25
            width: Math.min(implicitWidth + leftPadding, 260)
            text: root.body
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        // Progress bar for volume/brightness (progress >= 0), indented.
        Rectangle {
            visible: root.progress >= 0
            x: 25
            width: 120
            height: 4
            radius: 2
            color: Services.Color.mSurfaceVariant

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.progress))
                height: parent.height
                radius: 2
                color: Services.Color.mPrimary
                Behavior on width {
                    NumberAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing }
                }
            }
        }
    }
}
