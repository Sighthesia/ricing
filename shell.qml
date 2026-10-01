import QtQuick
import Quickshell
import Quickshell.Io
import "modules/lazerbar" as LazerBar
import "modules/bar" as Bar
import "modules/lock" as LockModule
import "services" as Services

// Mount the session lock and the desktop wallpaper behind the layout-driven top
// bar and notifications. Both are eager surfaces; everything else lives in the
// chrome component, which is built after the wallpaper reports its first reveal
// so the opening frames of a session cost two full-screen surfaces instead of
// all of them.
//
// Order matters here. The lock is the session's first screen: it engages from
// the bootstrap layer, so a fresh login never assembles a desktop that the lock
// would immediately cover. The wallpaper reveal still runs underneath it, which
// means the desktop is already settled when the user authenticates.
ShellRoot {
    id: root

    // Inject the wallpaper palette into the shared LazerTheme singleton.
    // Keeps LazerTheme loadable without Quickshell in qmltestrunner while
    // restoring the live theme-color path in the compositor. Stays on the root
    // because the wallpaper floor resolves its color through these bindings
    // during bootstrap, before any chrome exists.
    //
    // The glow pulse's clock is injected the same way: the service owns the one
    // timeline so the notification card and the bar cannot drift apart, but the
    // sweep length belongs to the motion tokens.
    Component.onCompleted: {
        LazerBar.LazerTheme.settingsService = Services.SettingsService
        LazerBar.LazerTheme.colorService = Services.Color
        Services.RipplePulseService.duration = LazerBar.MotionTokens.glowSweep
        // Ask for the session-start lock now rather than from the chrome. It
        // waits for a screen and for the persisted session marker on its own, so
        // calling it early is safe and a reload inside an already-locked session
        // still resolves to "do nothing".
        if (!lockModule.selfTestEnabled)
            Qt.callLater(() => lockModule.startupLock())
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
            chromeLoader.active = true
        }
    }

    // The compositor-enforced session lock, one surface per screen. Mounted here
    // rather than in the chrome so the lock owns the `lock` IPC target from the
    // first turn: a keybind or `afloat-ipc lock` during bootstrap reaches the real
    // owner instead of a stand-in that has to queue and replay the request.
    LockModule.Lock {
        id: lockModule
    }

    // Builds the chrome exactly once, behind the wallpaper reveal.
    Loader {
        id: chromeLoader
        active: false
        sourceComponent: chromeComponent
    }

    // Read-only window onto the fullscreen auto-hide chain, so the live state can
    // be inspected from outside instead of inferred. Logs the service verdicts
    // alongside what each bar screen resolves from them, which is the join the
    // feature depends on (niri's output connector vs Quickshell's screen name).
    //
    // Prints instead of returning: Quickshell rejects a non-void IPC handler and
    // calls it with no receiver, so a returning `state()` looks like a silent
    // no-op. The shell's own stdout carries the console.log.
    IpcHandler {
        target: "debugFullscreenBar"

        function state() {
            const verdicts = Services.NiriService.fullscreenOutputs
            const screens = Quickshell.screens
            const ws = Services.NiriService.workspaces
            const wins = Services.NiriService.windows

            const rows = []
            for (let i = 0; i < screens.length; i++) {
                const name = String(screens[i].name || "")
                rows.push(name + "->fullscreen:"
                    + ((verdicts || {})[name] === true)
                    + ",matched:"
                    + Object.prototype.hasOwnProperty.call(verdicts || {}, name))
            }

            let activeWs = "-"
            let covering = "none"
            for (let i = 0; i < ws.count; i++) {
                const w = ws.get(i)
                if (!w.isActive)
                    continue
                activeWs = w.wsId + "@" + w.output
                for (let k = 0; k < wins.count; k++) {
                    const win = wins.get(k)
                    if (String(win.workspaceId) !== String(w.wsId))
                        continue
                    covering = win.appId + " " + win.tileWidth + "x" + win.tileHeight
                }
            }

            console.log("[fsbar] settingEnabled="
                + (Services.SettingsService.bar.autoHideFullscreen === true)
                + " outputSizes=" + JSON.stringify(Services.NiriService.outputSizes)
                + " verdicts=" + JSON.stringify(verdicts)
                + " screens=[" + rows.join(" | ") + "]"
                + " activeWs=" + activeWs
                + " coveringTile=" + covering)

            // The bar's own reveal chain. `fullscreenActive` is what the bar
            // resolved; the rest is whether the state machine and the painted
            // slide actually followed it.
            const bars = Services.BarDebugState.bars
            const lines = []
            for (let i = 0; i < bars.length; i++) {
                const b = bars[i]
                lines.push(b.screenName
                    + "{fullscreenActive:" + b.fullscreenActive
                    + ",autoHideEnabled:" + b.autoHideEnabled
                    + ",revealed:" + b.revealed
                    + ",revealProgress:" + b.revealProgress
                    + ",pinned:" + b.pinned
                    + ",state:" + JSON.stringify(b.state) + "}")
            }
            console.log("[fsbar] bars=[" + lines.join(" | ") + "]")
        }
    }

    // Every surface that is not the wallpaper or the lock, in the order they
    // must stack: overview backdrop, bar, notifications, corner bezel.
    Component {
        id: chromeComponent

        Item {
            // Service warmup lives here rather than at root completion: these
            // entry points (and the lazily instantiated singletons they force
            // alive) must not occupy the wallpaper-first scene build. They run
            // behind the lock screen, so a session that starts locked has its
            // desktop already warm by the time the user authenticates.
            Component.onCompleted: {
                Services.LauncherService.primeApps()
                Services.ClipboardService.warmup()
                // Start the hold-key listener now, so the evdev bridge is
                // already reading the keyboard by the time the user reaches for
                // the hint key. QML singletons are lazy, so naming the property
                // is what spawns the bridge; the value itself is unused here.
                Services.WindowHintService.hintHeld
            }

            // Defer external app-theme work until the chrome has yielded a few
            // frames. gsettings, KDE/Niri sync, and template rendering are not
            // part of the shell's first-paint path and can otherwise compete
            // with the just-finished wallpaper transition.
            Timer {
                interval: LazerBar.MotionTokens.slow * 5
                repeat: false
                running: true
                onTriggered: {
                    Services.AppThemeService.apply()
                    Services.AppThemeService.pushSystemTheme()
                }
            }

            // Blurred/tinted wallpaper niri renders inside its overview backdrop.
            LazerBar.OverviewBackgroundWindow {}

            Bar.TopBar {}

            LazerBar.NotificationHost {}

            // Fake rounded display corners. This surface paints only the corners
            // the bar does not physically cover: two overlay-layer surfaces
            // cannot be ordered against each other by the client, so the bar
            // paints its own corners from its own window. See TopBar.qml.
            LazerBar.ScreenRoundedCorners {}
        }
    }
}
