import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// Create one non-exclusive notification host for every compositor screen.
Variants {
    id: root
    model: Quickshell.screens

    // Keep notification geometry local to the screen and out of the bar layout.
    Scope {
        id: screenScope
        required property var modelData

        // Commit only the visible stack bounds to the layer-shell surface.
        PanelWindow {
            id: notificationWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: notificationStack.implicitWidth
            implicitHeight: Math.max(1, notificationStack.implicitHeight)
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: Services.NotificationService.notificationTop
                bottom: Services.NotificationService.notificationBottom
                left: Services.NotificationService.notificationLeft
                right: Services.NotificationService.notificationRight
            }
            margins {
                top: Services.NotificationService.notificationTop
                    ? (Services.SettingsService.bar.position === "top"
                       ? Math.max(8, Number(Services.SettingsService.bar.height) + 12) : 16) : 8
                bottom: Services.NotificationService.notificationBottom
                    ? (Services.SettingsService.bar.position === "bottom"
                       ? Math.max(8, Number(Services.SettingsService.bar.height) + 12) : 16) : 8
                left: Services.NotificationService.notificationLeft ? 16 : 8
                right: Services.NotificationService.notificationRight ? 16 : 8
            }
            mask: Region { item: notificationStack.implicitHeight > 0 ? notificationStack : null }

            // Stack only the cards, leaving the rest of the screen pointer-transparent.
            LazerNotificationStack {
                id: notificationStack
                anchors.fill: parent
                stackAtTop: Services.NotificationService.notificationTop
                popupModel: Services.NotificationService.popupList
                onPopupDismissRequested: Services.NotificationService.dismissPopup(notifId)
            }
        }
    }
}
