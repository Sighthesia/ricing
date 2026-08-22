import QtQuick
import Quickshell
import Quickshell.Wayland
import "../lazerbar"
import "../../services" as Services

// Mount one layout-driven bar window per screen.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: barWindow

        required property var modelData

        readonly property bool floating: Services.SettingsService.bar.floating
        readonly property int floatingMargin: floating
                ? Math.max(0, Math.min(24, Number(Services.SettingsService.bar.floatingMargin) || 0)) : 0
        readonly property int effectiveHeight:
            Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))

        screen: modelData
        color: "transparent"
        implicitHeight: effectiveHeight
        exclusiveZone: floating ? 0 : implicitHeight
        anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true; right: true }
        margins { top: floatingMargin; bottom: floatingMargin; left: floatingMargin; right: floatingMargin }

        // Paint the continuous sharp bar silhouette behind every widget.
        Rectangle {
            anchors.fill: parent
            radius: 0
            color: Services.SettingsService.appearance.colorScheme === "light" ? "#F2F0F5" : LazerTheme.bgDark
            opacity: Math.max(0.35, Math.min(1, Services.SettingsService.panelSurfaceOpacity))

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        BarContent {
            anchors.fill: parent
            screenName: barWindow.modelData.name || ""
        }
    }
}
