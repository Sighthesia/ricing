import QtQuick
import Quickshell
import "modules/lazerbar" as LazerBar
import "modules/bar" as Bar
import "modules/lock" as LockModule
import "services" as Services

// Mount the desktop wallpaper behind the layout-driven top bar and notifications.
ShellRoot {
    // Inject the wallpaper palette into the shared LazerTheme singleton.
    // Keeps LazerTheme loadable without Quickshell in qmltestrunner while
    // restoring the live theme-color path in the compositor.
    Component.onCompleted: {
        LazerBar.LazerTheme.settingsService = Services.SettingsService
        LazerBar.LazerTheme.colorService = Services.Color
        // QML singletons are lazily instantiated: touching the service here
        // is what actually brings the app-theme sync (and its Connections)
        // to life — nothing else references it.
        Services.AppThemeService
    }

    LazerBar.WallpaperBackground {}

    // Blurred/tinted wallpaper niri renders inside its overview backdrop.
    LazerBar.OverviewBackgroundWindow {}

    Bar.TopBar {}

    LazerBar.NotificationHost {}

    // Compositor-enforced session lock; creates one surface per screen.
    LockModule.Lock {}
}
