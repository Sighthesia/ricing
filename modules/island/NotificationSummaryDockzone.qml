import QtQuick
import "../../services" as Services
import "../common" as Common

// Compact collapsed island notification summary.
Item {
    id: root

    readonly property bool showSummary: Services.NotificationService.unreadCount > 0
        && !Services.NotificationService.summaryDismissed
        && !Services.TransientMessageService.active

    implicitWidth: showSummary ? summaryCapsule.implicitWidth : 0
    implicitHeight: showSummary ? 28 : 0
    visible: showSummary

    // Keep the notification entry compact and vertically centered.
    Common.GlassCapsule {
        id: summaryCapsule

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showSummary
        radius: 12
        borderWidth: 1
        clipContent: true
        surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
        outlineColor: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.72)

        implicitWidth: contentRow.implicitWidth + 24
        implicitHeight: 28

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

        // Render the unread badge without inline persistent message text.
        Row {
            id: contentRow

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Unread count badge.
            Rectangle {
                visible: Services.NotificationService.unreadCount > 0
                width: 16
                height: 16
                radius: 8
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
        }
    }
}
