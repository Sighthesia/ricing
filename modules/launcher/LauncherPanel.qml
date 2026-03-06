import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.modules.bar

// Launcher overlay panel — centred below the bar, opens/closes via LauncherService.isOpen.
// IPC: `qs ipc call launcher.toggle` / `qs ipc call launcher.openClipboard`
AnimatedPanelBase {
    id: panelWindow

    anchors { top: true; horizontalCenter: true }
    margins { top: Theme.barHeight }

    implicitWidth: 640
    implicitHeight: 480
    focusable: true

    active: LauncherService.isOpen

    onPanelOpening: _core.openPanel()
    onPanelClosing: _core.closePanel()

    // Panel background card
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // Inner highlight border
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }
    }

    LauncherCore {
        id: _core
        anchors {
            fill: parent
            topMargin: 4
            leftMargin: 4
            rightMargin: 4
            bottomMargin: 4
        }
    }
}
