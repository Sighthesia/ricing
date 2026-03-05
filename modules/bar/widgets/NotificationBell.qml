import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Bar widget — bell icon with unread badge, toggles the notification history panel.
// Right-click toggles Do-Not-Disturb mode.
//
// HoverRevealHighlight and ClickRipple are NOT imported here because they live in
// modules/bar/ (parent dir) which is inaccessible to a subdirectory without a module
// import. Hover feedback is implemented inline to keep this widget self-contained,
// matching the pattern used by Clock.qml and WorkspaceWidget.qml.
Rectangle {
    id: bell

    color: Colors.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: _row.implicitWidth + Theme.widgetPadding * 2

    // Inline hover highlight — replaces HoverRevealHighlight which can't be imported
    // from a widgets/ subdirectory without a circular module import.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.highlight
        opacity: _area.containsMouse ? Colors.highlightAlpha : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
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

        // Bell icon — uses Theme.fontMono (JetBrainsMono Nerd Font by default) so that
        // Nerd Font private-use glyphs render correctly; Theme.fontFamily is a CJK font
        // that does not contain these codepoints.
        Item {
            implicitWidth: _bellText.implicitWidth
            implicitHeight: _bellText.implicitHeight

            Text {
                id: _bellText
                text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                font.family: Theme.fontMono
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
