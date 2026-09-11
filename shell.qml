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
        // QML singletons are lazily instantiated and an unused bare
        // reference can be dropped: run the sync service's entry point
        // explicitly so the instance (and its Connections) come to life.
        Services.AppThemeService.apply()
    }

    LazerBar.WallpaperBackground {}

    // Blurred/tinted wallpaper niri renders inside its overview backdrop.
    LazerBar.OverviewBackgroundWindow {}

    Bar.TopBar {}

    LazerBar.NotificationHost {}

    // Compositor-enforced session lock; creates one surface per screen.
    LockModule.Lock {}
}
