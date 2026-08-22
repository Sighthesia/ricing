import QtQuick
import Quickshell
import Quickshell.Io
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

        // Commit only the visible stack bounds to the input mask; keep the
        // window a full screen column so flung cards can fall past the stack
        // without being clipped by the layer surface edge.
        PanelWindow {
            id: notificationWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: notificationStack.implicitWidth
            implicitHeight: Math.max(1, screenScope.modelData.height)
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

            // Stack only the cards; the stack keeps its content height so the
            // input mask stays limited to visible notification cards.
            LazerNotificationStack {
                id: notificationStack
                anchors.top: Services.NotificationService.notificationTop ? parent.top : undefined
                anchors.bottom: Services.NotificationService.notificationBottom ? parent.bottom : undefined
                anchors.horizontalCenter: parent.horizontalCenter
                stackAtTop: Services.NotificationService.notificationTop
                popupModel: Services.NotificationService.popupList
            onPopupDismissRequested: Services.NotificationService.dismissPopup(notifId)
        }
        }
    }
}
