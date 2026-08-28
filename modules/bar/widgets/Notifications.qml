import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Notification bell with an unread diamond and do-not-disturb toggle.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property bool dnd: Services.NotificationService.dndEnabled
    readonly property int unread: Services.NotificationService.unreadCount

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: true

    onClicked: Services.NotificationService.dndEnabled = !root.dnd

    implicitWidth: LazerTheme.barWidgetHeight

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = root.unread > 0 ? root.unread + " unread" : "No unread"
        if (root.dnd) summaryText += " \u00B7 DND"
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: "Notifications",
            iconSource: Qt.resolvedUrl("../../lazerbar/icons/bell.svg"),
            summary: summaryText,
            actionKind: "notifications",
            anchorX: centerX,
            payload: {
                dndEnabled: Services.NotificationService.dndEnabled,
                unreadCount: Services.NotificationService.unreadCount,
                notificationService: Services.NotificationService,
                onToggleDnd: function() { Services.NotificationService.dndEnabled = !Services.NotificationService.dndEnabled },
                onMarkAllRead: function() { Services.NotificationService.markAllRead() }
            }
        }
    }

    onHoveredChanged: {
        if (hovered) popupRequested(buildHoverIntent())
        else popupCloseRequested()
    }

    // Update anchor while the bar layout moves.
    onXChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())

    Item {
        id: bellHost

        anchors.centerIn: parent
        width: LazerTheme.barWidgetHeight - 6
        height: LazerTheme.barWidgetHeight - 6

        Image {
            anchors.centerIn: parent
            width: LazerTheme.barGlyphSize
            height: LazerTheme.barGlyphSize
            source: Qt.resolvedUrl("../../lazerbar/icons/bell.svg")
            opacity: root.dnd ? 0.4 : 0.9

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        // Unread state uses a sharp accent diamond, never a rounded badge.
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            width: 7
            height: 7
            radius: 0
            rotation: 45
            color: LazerTheme.osuPink
            visible: root.unread > 0 && !root.dnd
        }
    }

}
