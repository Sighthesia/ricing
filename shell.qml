import QtQuick
import Quickshell
import "modules/lazerbar" as LazerBar
import "modules/bar" as Bar
import "services" as Services

// Mount the desktop wallpaper behind the layout-driven top bar and notifications.
ShellRoot {
    // Inject the wallpaper palette into the shared LazerTheme singleton.
    // Keeps LazerTheme loadable without Quickshell in qmltestrunner while
    // restoring the live theme-color path in the compositor.
    Component.onCompleted: {
        LazerBar.LazerTheme.settingsService = Services.SettingsService
        LazerBar.LazerTheme.colorService = Services.Color
    }

    LazerBar.WallpaperBackground {}

    // Blurred/tinted wallpaper niri renders inside its overview backdrop.
    LazerBar.OverviewBackgroundWindow {}

    Bar.TopBar {}

    LazerBar.NotificationHost {}
}
