import QtQuick
import Quickshell
import "../../services" as Services
import "../common" as Common

// Compact collapsed island notification summary.
Item {
    id: root

    readonly property bool showSummary: Services.NotificationService.unreadCount > 0
        && !Services.NotificationService.summaryDismissed
        && !Services.TransientMessageService.active
    readonly property string rawIcon: Services.NotificationService.latestIcon
    readonly property string iconSource: {
        if (root.rawIcon === "") return ""
        if (root.rawIcon.indexOf("/") !== -1 || root.rawIcon.indexOf(":") !== -1)
            return root.rawIcon
        return Quickshell.iconPath(root.rawIcon, true)
    }
    readonly property string appName: Services.NotificationService.latestAppName !== ""
        ? Services.NotificationService.latestAppName
        : "通知"
    readonly property string messageText: Services.NotificationService.latestSummary !== ""
        ? Services.NotificationService.latestSummary
        : Services.NotificationService.latestBody

    implicitWidth: showSummary ? summaryCapsule.implicitWidth : 0
    implicitHeight: showSummary ? 34 : 0
    visible: showSummary

    // Keep the notification entry compact and vertically centered.
    Common.GlassCapsule {
        id: summaryCapsule

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showSummary
        radius: 14
        borderWidth: 1
        clipContent: true
        surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
        outlineColor: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.72)

        implicitWidth: Math.min(280, contentRow.implicitWidth + 24)
        implicitHeight: 34

        // Open the shared notification center.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Services.NotificationService.markAllRead()
                Services.IslandService.showNotifications()
            }
        }

        // Render the latest notification source and content.
        Row {
            id: contentRow

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Unread count badge.
            Rectangle {
                visible: Services.NotificationService.unreadCount > 0
                width: 18
                height: 18
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.18)
                border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.7)
                border.width: 1

                Services.FluidText {
                    anchors.centerIn: parent
                    text: Services.NotificationService.unreadCount > 99 ? "99+" : String(Services.NotificationService.unreadCount)
                    color: Services.Color.mPrimary
                    basePixelSize: 8
                    font.bold: true
                }
            }

            // Latest app icon or fallback initial.
            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    visible: root.iconSource !== ""
                    source: root.iconSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 20
                    sourceSize.height: 20
                }

                Services.FluidText {
                    anchors.centerIn: parent
                    visible: root.iconSource === ""
                    text: root.appName.charAt(0).toUpperCase()
                    color: Services.Color.mOnSurface
                    basePixelSize: 10
                    font.bold: true
                }
            }

            // Latest message summary.
            Column {
                width: Math.max(0, parent.width - 54)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Services.FluidText {
                    width: parent.width
                    text: root.appName
                    color: Services.Color.mOnSurface
                    basePixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                }

                Services.FluidText {
                    width: parent.width
                    text: root.messageText !== "" ? root.messageText : "新消息"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }
    }
}
