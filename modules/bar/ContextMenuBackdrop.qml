import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// Full-screen transparent overlay that closes the context menu
// when the user clicks anywhere outside it.
// Sits between bar (Top layer) and the popup window.
PanelWindow {
    anchors { left: true; top: true; right: true; bottom: true }
    // exclusiveZone: -1 means this window does not push other surfaces away.
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: BarLayoutService.contextMenuOpen || BarLayoutService.trayMenuOpen

    MouseArea {
        anchors.fill: parent
        // Any click outside the popup closes the menu.
        onClicked: {
            BarLayoutService.contextMenuOpen = false
            BarLayoutService.trayMenuOpen = false
        }
    }
}
