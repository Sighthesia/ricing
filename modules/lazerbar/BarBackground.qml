import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// Reserve the workspace and paint the continuous top-bar silhouette.
PanelWindow {
    id: root
    required property var targetScreen
    screen: targetScreen
    color: "transparent"
    implicitHeight: Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))
    exclusiveZone: Services.SettingsService.bar.floating ? 0 : implicitHeight
    anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true; right: true }
    margins { top: Services.SettingsService.bar.floating ? Math.max(0, Math.min(24, Services.SettingsService.bar.floatingMargin)) : 0; bottom: Services.SettingsService.bar.floating ? Math.max(0, Math.min(24, Services.SettingsService.bar.floatingMargin)) : 0; left: Services.SettingsService.bar.floating ? Math.max(0, Math.min(24, Services.SettingsService.bar.floatingMargin)) : 0; right: Services.SettingsService.bar.floating ? Math.max(0, Math.min(24, Services.SettingsService.bar.floatingMargin)) : 0 }
    mask: Region {}

    // Opaque like kitty's `background` (same mSurface token): any
    // translucency lets the wallpaper bleed in and drift off kitty.
    Rectangle {
        anchors.fill: parent
        color: Services.SettingsService.effectiveColorScheme === "light" ? LazerTheme.bgLight : LazerTheme.bgDark
        opacity: 1
        radius: 0

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }
}
