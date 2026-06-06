import QtQuick
import Quickshell
import "../../services" as Services
import "../common" as Common

// Compact collapsed island notification summary.
Item {
    id: root

    readonly property int stickyCount: Services.NotificationService.stickyCount
    readonly property int carouselIndex: Services.NotificationService.stickyCarouselIndex
    readonly property int messageCount: Services.NotificationService.messageCount
    readonly property var currentSticky: Services.NotificationService.currentStickyNotification()
    readonly property var latestMessage: Services.NotificationService.latestNotification()
    readonly property var displayMessage: stickyCount > 0 ? currentSticky : latestMessage
    readonly property string currentStickyNumber: stickyCount > 0 ? ((carouselIndex % stickyCount) + 1) + "/" + stickyCount : ""
    readonly property string currentStickyIconSource: {
        const icon = displayMessage ? (displayMessage.icon || "") : ""
        if (icon === "") return ""
        if (icon.indexOf("/") !== -1 || icon.indexOf(":") !== -1)
            return icon
        return Quickshell.iconPath(icon, true)
    }
    readonly property string currentStickyTitle: displayMessage
        ? (displayMessage.appName || displayMessage.summary || "通知")
        : ""
    readonly property string currentStickyBody: displayMessage
        ? (displayMessage.body || displayMessage.summary || "")
        : ""
    readonly property bool hasMessages: messageCount > 0

    readonly property bool showSummary: hasMessages
        && !Services.NotificationService.summaryDismissed
        && !Services.TransientMessageService.active

    implicitWidth: showSummary ? Math.max(280, summaryCapsule.implicitWidth) : 0
    implicitHeight: showSummary ? 28 : 0
    visible: showSummary

    // Advance the shared sticky carousel without altering layout.
    Timer {
        id: carouselTimer
        interval: 3500
        repeat: true
        running: root.showSummary && root.stickyCount > 1
        onTriggered: Services.NotificationService.advanceStickyCarousel()
    }

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

        implicitWidth: contentRow.implicitWidth + 18
        implicitHeight: 24

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

        // Render the unread badge and current sticky message on one compact line.
        Row {
            id: contentRow

            anchors.left: parent.left
            anchors.leftMargin: 10
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

                Text {
                    anchors.centerIn: parent
                    text: Services.NotificationService.unreadCount > 99 ? "99+" : String(Services.NotificationService.unreadCount)
                    color: Services.Color.mPrimary
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            // Current sticky icon or source monogram.
            Item {
                visible: root.displayMessage !== null
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16

                Image {
                    anchors.fill: parent
                    visible: root.currentStickyIconSource !== ""
                    source: root.currentStickyIconSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 16
                    sourceSize.height: 16
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.currentStickyIconSource === ""
                    text: root.currentStickyTitle !== "" ? root.currentStickyTitle.charAt(0).toUpperCase() : "N"
                    color: Services.Color.mOnSurface
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            // Current sticky text stays inline with the other center widgets.
            Column {
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: 210
                    text: root.currentStickyNumber !== ""
                        ? (root.currentStickyNumber + " " + root.currentStickyTitle)
                        : root.currentStickyTitle
                    color: Services.Color.mOnSurface
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: 210
                    text: root.currentStickyBody
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}
