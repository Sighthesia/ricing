import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.modules.bar

// Top-level layer-shell bar window that hosts the composed bar content.
PanelWindow {
    id: barWindow

    readonly property bool _debugLogging:
        (Quickshell.env("DYMICSHELL_SUPERISLAND_DEBUG") || "").trim() === "1"

    anchors { left: true; top: true; right: true }
    color: "transparent"

    // Expand downward during widget flashes (non-exclusive zone).
    implicitHeight: Theme.barHeight + BarLayoutService.barTransientExtension
    exclusiveZone: Theme.barHeight

    function _logBarHeightState(context) {
        if (!barWindow._debugLogging)
            return

        console.log("[DymicShell:BarWindowHeight]", JSON.stringify({
            context: context || "",
            themeBarHeight: Math.round(Theme.barHeight || 0),
            barTransientExtension: Math.round(BarLayoutService.barTransientExtension || 0),
            implicitHeight: Math.round(barWindow.implicitHeight || 0),
            exclusiveZone: Math.round(barWindow.exclusiveZone || 0)
        }))
    }

    Component.onCompleted: _logBarHeightState("completed")
    Connections {
        target: BarLayoutService
        function onBarTransientExtensionChanged() {
            barWindow._logBarHeightState("barTransientExtensionChanged")
        }
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus:
        IslandOverlayService.state !== "closed"
            ? (IslandOverlayService.mode === "launcher"
                ? WlrKeyboardFocus.Exclusive
                : ((IslandOverlayService.mode === "settings"
                    || IslandOverlayService.mode === "control-center"
                    || IslandOverlayService.mode === "notifications"
                    || IslandOverlayService.mode === "session-control"
                    || IslandOverlayService.mode === "break-reminder")
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None))
            : WlrKeyboardFocus.None

    BarContent {
        anchors.fill: parent
    }
}
