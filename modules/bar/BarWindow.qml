import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.modules.bar

PanelWindow {
    id: barWindow

    anchors { left: true; top: true; right: true }
    color: "transparent"

    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    BarContent {
        anchors.fill: parent
    }
}
