import QtQuick
import Quickshell
import Quickshell.Io
import "modules/lazerbar" as LazerBar
import "modules/bar" as Bar
import "modules/lock" as LockModule
import "services" as Services

// Mount the desktop wallpaper behind the layout-driven top bar and notifications.
// The wallpaper is the only eager surface: everything else lives in the chrome
// component, which is built after the wallpaper reports its first reveal so the
// opening frames of a session cost one full-screen surface instead of all of it.
ShellRoot {
    id: root

    // The chrome's LockModule.Lock, published once the chrome mounts, and a
    // lock request that arrived before that. Both live on the root rather than
    // on the IpcHandler because Quickshell rejects non-void handler functions
    // and warns about every signal a handler exposes over IPC.
    property var lockOwner: null
    property bool queuedLockRequest: false

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
            if (!bootReady || chromeLoader.active)
                return
            // The lock moves into the chrome, so the bridge has to hand the
            // `lock` target back first: Quickshell keeps one handler per target
            // and displaces the earlier registration with a warning.
            bootstrapLockBridge.enabled = false
            chromeLoader.active = true
        }
    }

    // Builds the chrome exactly once, behind the wallpaper reveal.
    Loader {
        id: chromeLoader
        active: false
        sourceComponent: chromeComponent
    }

    // Stands in for the lock IPC surface that the chrome's LockModule.Lock owns
    // once it exists. Compositor keybinds and `afloat-ipc lock` reach the session
    // lock through the `lock` target, and moving that handler behind the
    // wallpaper reveal would otherwise drop every request made during bootstrap.
    // This bridge owns the target only until the chrome mounts, then disables
    // itself so the real handler is the only one answering.
    IpcHandler {
        id: bootstrapLockBridge
        target: "lock"

        // A lock asked for before the chrome existed, retained instead of
        // dropped. Coalesced to one request: repeated locks are no-ops anyway.
        function lock() {
            if (root.lockOwner !== null) {
                root.lockOwner.lock()
                return
            }
            // Say so once, so a request that is waiting is never invisible.
            if (!root.queuedLockRequest)
                console.log("[afloat:lock] holding a lock request until the wallpaper bootstrap finishes")
            root.queuedLockRequest = true
        }

        // Nothing can be locked before the chrome exists, so releasing is a
        // no-op and the state is known to be unlocked, exactly as on a freshly
        // started lock.
        function unlock() {}

        function isLocked(): bool {
            return root.lockOwner !== null && root.lockOwner.isLocked()
        }

        // The self-test entry point spawns a second shell process and only makes
        // sense against an already-revealed desktop, so it stays with the real
        // handler. Quickshell reports an unknown function as an error rather than
        // swallowing the call, which is the honest answer during bootstrap.
        function test() {
            console.warn("[afloat:lock] the lock self-test is unavailable during wallpaper bootstrap")
        }
    }

    // Adopt the chrome's lock as the bridge's forward target, replaying a
    // request that arrived while the bridge was the only `lock` handler.
    function adoptLockOwner(owner) {
        root.lockOwner = owner
        if (!root.queuedLockRequest)
            return
        root.queuedLockRequest = false
        console.log("[afloat:lock] replaying a lock request taken during wallpaper bootstrap")
        owner.lock()
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
                // Hand the bootstrap bridge this lock so a request taken while
                // the chrome did not exist can be replayed into the real owner.
                root.adoptLockOwner(lockModule)
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
