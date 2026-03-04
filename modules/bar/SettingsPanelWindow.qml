import QtQuick
import qs.config
import qs.services
import "./settings"

// Floating settings panel that appears below the Bar at the right side of the screen.
// Uses AnimatedPanelBase for a drop-down expand/collapse animation.
AnimatedPanelBase {
    id: panelWindow

    // Sit at top-right; top margin pushes the panel below the bar
    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth: 480
    // Fixed height avoids per-frame Wayland surface resize during expand/collapse
    // animations. Content scrolls internally via AppearancePage's Flickable.
    implicitHeight: 580

    // Keyboard input for hex color editing
    focusable: true

    // Logical open/close trigger — AnimatedPanelBase manages actual window visibility
    active: BarLayoutService.activePanel === "config"

    // Panel background card
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // Subtle inner shadow effect: second border inset
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }

        // Clicking blank space inside the panel clears any jump-to highlights
        // and dismisses the search dropdown (unfocuses search field).
        MouseArea {
            anchors.fill: parent
            onClicked: {
                content.clearAllHighlights()
                content.dismissSearch()
            }
        }
    }

    SettingsPanelContent {
        id: content
        anchors {
            fill: parent
            topMargin: 10
            leftMargin: 4
            rightMargin: 8
            bottomMargin: 10
        }
    }
}
