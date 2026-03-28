import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.modules.bar

PanelWindow {
    id: barWindow

    anchors { left: true; top: true; right: true }
    color: "transparent"

    // Expand downward during widget flashes (non-exclusive zone).
    implicitHeight: Theme.barHeight + BarLayoutService.barTransientExtension
    exclusiveZone: Theme.barHeight

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus:
        (IslandOverlayService.mode === "launcher" || IslandOverlayService.mode === "settings")
        && IslandOverlayService.state !== "closed"
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None

    BarContent {
        anchors.fill: parent
    }
}
