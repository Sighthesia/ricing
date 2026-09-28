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
        // window a full screen column plus a left fly-out reserve so flung
        // cards are not clipped by the layer surface edge mid-fall.
        PanelWindow {
            id: notificationWindow
            screen: screenScope.modelData
            color: "transparent"
            WlrLayershell.namespace: "afloat-notifications"
            implicitWidth: notificationStack.implicitWidth + 560
            implicitHeight: Math.max(1, screenScope.modelData.height)
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: Services.NotificationService.notificationTop
                bottom: Services.NotificationService.notificationBottom
                right: Services.NotificationService.notificationRight
                left: Services.NotificationService.notificationLeft
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

            // Publish the claimed region in screen coordinates for diagnostics.
            // Without this, "the pointer was stolen by another surface" stays an
            // assumption; with it, a departure landing inside this rect names the
            // thief — which is how the notification theory was ruled out (the
            // failure happened with no notification on screen at all).
            // Note this host does NOT stand down for the bar popup: the
            // notification host and the popup share the Top layer, but the
            // surface that actually covers the tray column is afloat-bar, which
            // is on the Overlay layer and so above both.
            function publishClaimedRegion() {
                if (notificationStack.implicitHeight <= 0) {
                    PopupInputArbitration.releaseInputRegion()
                    return
                }
                var o = mapToItem(null, notificationStack.x, notificationStack.y)
                PopupInputArbitration.claimInputRegion(o.x, o.y,
                    notificationStack.width, notificationStack.height)
            }
            onVisibleChanged: publishClaimedRegion()

            // Re-publish whenever the claimed rect moves or resizes. A card
            // appearing is exactly the moment the region becomes non-empty and
            // the compositor re-evaluates pointer focus, so a stale rect here
            // would name the wrong thief at the wrong time.
            Connections {
                target: notificationStack
                function onXChanged() { notificationWindow.publishClaimedRegion() }
                function onYChanged() { notificationWindow.publishClaimedRegion() }
                function onWidthChanged() { notificationWindow.publishClaimedRegion() }
                function onImplicitHeightChanged() { notificationWindow.publishClaimedRegion() }
            }

            // Stack only the cards; the stack keeps its content height so the
            // input mask stays limited to visible notification cards. It hugs
            // whichever horizontal edge the host surface is pinned to, so the
            // extra fly-out reserve stays transparent on the fling side.
            LazerNotificationStack {
                id: notificationStack
                anchors.top: Services.NotificationService.notificationTop ? parent.top : undefined
                anchors.bottom: Services.NotificationService.notificationBottom ? parent.bottom : undefined
                anchors.right: Services.NotificationService.notificationRight ? parent.right : undefined
                anchors.left: Services.NotificationService.notificationLeft ? parent.left : undefined
                stackAtTop: Services.NotificationService.notificationTop
                popupModel: Services.NotificationService.popupList
                onPopupDismissRequested: notifId => Services.NotificationService.dismissPopup(notifId)
                onPopupActionRequested: (notifId, identifier) =>
                    Services.NotificationService.invokePopupAction(notifId, identifier)

                // Expired popups leave with the same fling as a manual close;
                // entries without a live delegate are dropped immediately.
                Connections {
                    target: Services.NotificationService
                    function onPopupCloseRequested(notifId) {
                        if (!notificationStack.closeAnimated(notifId))
                            Services.NotificationService.dismissPopup(notifId)
                    }
                }
            }
        }
    }
}
