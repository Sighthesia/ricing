import QtQuick
import Quickshell
import "modules/lazerbar" as LazerBar
import "modules/bar" as Bar
import "modules/lock" as LockModule
import "services" as Services

// Mount the desktop wallpaper behind the layout-driven top bar and notifications.
// The wallpaper is the only eager surface: everything else lives in the chrome
// component, which is built after the wallpaper reports its first reveal so the
// opening frames of a session cost one full-screen surface instead of all of it.
ShellRoot {
    // Inject the wallpaper palette into the shared LazerTheme singleton.
    // Keeps LazerTheme loadable without Quickshell in qmltestrunner while
    // restoring the live theme-color path in the compositor. Stays on the root
    // because the wallpaper floor resolves its color through these bindings
    // during bootstrap, before any chrome exists.
    Component.onCompleted: {
        LazerBar.LazerTheme.settingsService = Services.SettingsService
        LazerBar.LazerTheme.colorService = Services.Color
    }

    // Bootstrap layer: one full-screen wallpaper surface per screen, reporting
    // readiness once every present screen has settled its first reveal.
    LazerBar.WallpaperBackground {
        id: wallpaperBackground

        // Mount the chrome on the first report, and never unmount it. Readiness
        // is derived from the live screen list, so `active` bound straight to
        // bootReady would destroy a running shell whenever a screen is re-keyed
        // (resolution change) or unplugged, remounting every surface and
        // restarting every service. The guard keeps this one-way and idempotent.
        onBootReadyChanged: {
            if (bootReady && !chromeLoader.active)
                chromeLoader.active = true
        }
    }

    // Builds the chrome exactly once, behind the wallpaper reveal.
    Loader {
        id: chromeLoader
        active: false
        sourceComponent: chromeComponent
    }

    // Every surface that is not the wallpaper, in the order they must stack:
    // overview backdrop, bar, notifications, corner bezel, then the lock.
    Component {
        id: chromeComponent

        Item {
            // Service warmup lives here rather than at root completion: these
            // entry points (and the lazily instantiated singletons they force
            // alive) must not occupy the wallpaper-first scene build.
            Component.onCompleted: {
                // QML singletons are lazily instantiated and an unused bare
                // reference can be dropped: run the sync service's entry points
                // explicitly so the instance (and its Connections) come to life.
                Services.AppThemeService.apply()
                Services.AppThemeService.pushSystemTheme()
                Services.LauncherService.primeApps()
                Services.ClipboardService.warmup()
                if (!lockModule.selfTestEnabled)
                    Qt.callLater(() => lockModule.startupLock())
            }

            // Blurred/tinted wallpaper niri renders inside its overview backdrop.
            LazerBar.OverviewBackgroundWindow {}

            Bar.TopBar {}

            LazerBar.NotificationHost {}

            // Fake rounded display corners; mounted last so the bezel composites above
            // the wallpaper and the bar within the overlay layer.
            LazerBar.ScreenRoundedCorners {}

            // Compositor-enforced session lock; creates one surface per screen.
            LockModule.Lock {
                id: lockModule
            }
        }
    }
}
