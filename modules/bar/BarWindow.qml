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
        IslandOverlayService.state !== "closed"
            ? (IslandOverlayService.mode === "launcher"
                ? WlrKeyboardFocus.Exclusive
                : ((IslandOverlayService.mode === "settings" || IslandOverlayService.mode === "notifications")
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None))
            : WlrKeyboardFocus.None

    BarContent {
        anchors.fill: parent
    }
}
