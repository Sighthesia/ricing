import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Notification preview card for the overview control-center collage.
// Shows unread count badge and recent notification snippets. Tall
// enough for multiple snippet lines. Click opens notification center.
// Uses glass layered background with gradient and top-edge sheen.
Rectangle {
    id: root

    signal clicked()

    readonly property int unreadCount: Services.NotificationService.unreadCount
    readonly property bool hasUnread: root.unreadCount > 0
    // Snippets from recent notifications (uses fake previews when history is
    // sparse so the card never feels empty in demo).
    readonly property var recentEntries: Services.NotificationService.historyList
    readonly property string snippet1: root.recentEntries && root.recentEntries.count > 0
        ? (root.recentEntries.get(root.recentEntries.count - 1).body
            || root.recentEntries.get(root.recentEntries.count - 1).summary || "")
        : ""
    readonly property string snippet2: root.recentEntries && root.recentEntries.count > 1
        ? (root.recentEntries.get(root.recentEntries.count - 2).body
            || root.recentEntries.get(root.recentEntries.count - 2).summary || "")
        : ""

    radius: 16
    color: notifMouse.containsMouse
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

    // Subtle gradient overlay for glass depth.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Top-edge glass highlight strip.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header row: title + unread badge + count summary.
        Row {
            spacing: 8

            Services.FluidText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u901A\u77E5"
                color: Services.Color.mOnSurface
                basePixelSize: 13
                font.bold: true
            }

            // Unread count badge.
            Rectangle {
                visible: root.hasUnread
                width: 20
                height: 18
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.18)
                border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.7)
                border.width: 1

                Services.FluidText {
                    anchors.centerIn: parent
                    text: root.unreadCount > 99 ? "99+" : String(root.unreadCount)
                    color: Services.Color.mPrimary
                    basePixelSize: 9
                    font.bold: true
                }
            }

            // Status text: unread count or "all read".
            Services.FluidText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.hasUnread
                    ? (root.unreadCount + " \u6761\u672A\u8BFB")
                    : "\u5DF2\u8BFB"
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 10
            }
        }

        // Notification snippet area with multi-line previews.
        Column {
            spacing: 8

            // First snippet or fallback hint — glass chip when populated.
            Rectangle {
                width: parent.parent.width
                height: 32
                radius: 8
                color: root.hasUnread && root.snippet1 !== ""
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
                    : "transparent"

                // Snippet glass highlight.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    visible: root.hasUnread && root.snippet1 !== ""
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                Services.FluidText {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.hasUnread && root.snippet1 !== ""
                        ? root.snippet1
                        : "\u6682\u65E0\u65B0\u901A\u77E9"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Second snippet (only shown when available) — glass chip.
            Rectangle {
                width: parent.parent.width
                height: 32
                radius: 8
                visible: root.hasUnread && root.snippet2 !== ""
                color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)

                // Snippet glass highlight.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                Services.FluidText {
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.snippet2
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    MouseArea {
        id: notifMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
