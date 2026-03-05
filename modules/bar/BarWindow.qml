import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.modules.bar

PanelWindow {
    id: barWindow

    anchors { left: true; top: true; right: true }
    color: "transparent"

    // Extra 30px extends the surface below the bar for the workspace island expansion.
    // exclusiveZone stays at barHeight so other windows are not shifted down.
    // FIXME: hardcoded size — should derive from WorkspaceWidget's (_titleGap + _titleRowH + _padV).
    // Promote to a Theme.* token so the island and window surface stay in sync.
    implicitHeight: Theme.barHeight + 30
    exclusiveZone: Theme.barHeight

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    BarContent {
        anchors.fill: parent
    }
}
