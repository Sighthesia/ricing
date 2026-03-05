import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Bar widget — bell icon with unread badge, toggles the notification history panel.
// Right-click toggles Do-Not-Disturb mode.
Rectangle {
    id: bell

    color: Colors.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: _row.implicitWidth + Theme.widgetPadding * 2

    HoverRevealHighlight { anchors.fill: parent; hovered: _area.containsMouse }
    ClickRipple { id: _ripple; anchors.fill: parent }

    MouseArea {
        id: _area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            _ripple.triggerRipple(mouse.x, mouse.y)
            if (mouse.button === Qt.RightButton) {
                // FIXME: implement as a proper PopupWindow following BarContextMenu pattern
                NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                return
            }
            BarLayoutService.notificationHistoryOpen = !BarLayoutService.notificationHistoryOpen
        }
    }

    RowLayout {
        id: _row
        anchors.centerIn: parent
        spacing: 0

        // Bell icon — switches glyph when DND is active
        Item {
            implicitWidth: _bellText.implicitWidth
            implicitHeight: _bellText.implicitHeight

            Text {
                id: _bellText
                // FIXME: replace with proper Nerd Font / Material Symbols glyph when font is verified
                text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeIcon
                color: NotificationService.doNotDisturb ? Colors.textMuted : Colors.text
            }

            // Unread badge — small accent dot at top-right of icon
            Rectangle {
                anchors.top:   parent.top
                anchors.right: parent.right
                anchors.topMargin:   -2
                anchors.rightMargin: -2
                width: 8; height: 8
                radius: 4
                color: Colors.highlight
                visible: NotificationService.unreadCount > 0
            }
        }
    }
}
