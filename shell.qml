import QtQuick
import Quickshell
import Quickshell.Io
import "modules/lazerbar" as LazerBar
import "modules/lazerbar/StartupRevealLogic.js" as StartupReveal
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

    // ---- Startup stage coordination -------------------------------------
    //
    // One-way ladder, owned by the root because the root is the only object
    // that sees all three reporters: the wallpaper (its reveal settled), the
    // chrome (bar staged plus auxiliary surfaces mounted), and the lock (it
    // committed to its entry wave). `StartupReveal.advance()` is the whole
    // table; everything below is wiring, and every effect is latched, so a
    // duplicate report, a screen re-key or a hotplug cannot re-run any of it.
    //
    // Nothing here waits on palette extraction, launcher priming or an external
    // theme sync: those run after the wave, so the first screen never pays for
    // them and quiet-ready never depends on a process that may fail.
    property int startupStage: StartupReveal.Stages.lockedFloor
    property bool startupWallpaperReady: false
    property bool startupChromeReady: false
    property bool startupQuietReady: false
    // True once the bounded fallback below released a gate nothing ever
    // reported, so a degraded boot is visible in the log instead of silent.
    property bool startupFallbackUsed: false
    // The chrome gets its own latch rather than riding on the wallpaper gate:
    // the fallback can open that gate before any screen exists, and a screen
    // that arrives later must still get its chrome.
    property bool _chromeMounted: false

    // One ladder step. Idempotent by construction: `advance()` returns the
    // current stage for an unknown or out-of-order event, and an unchanged
    // result is not written back.
    function advanceStartup(event) {
        const next = StartupReveal.advance(root.startupStage, event)
        if (next === root.startupStage)
            return root.startupStage
        root.startupStage = next
        return next
    }

    // Build the chrome exactly once, behind the wallpaper reveal.
    function mountChrome() {
        if (root._chromeMounted)
            return
        root._chromeMounted = true
        chromeLoader.active = true
        root.advanceStartup(StartupReveal.Events.chromeMounted)
    }

    // The wallpaper reports every terminal boot outcome — reveal, empty, error,
    // unchanged, reduced motion — so this is the normal path and not a special
    // case; the guard is what keeps it one-way when a screen re-key re-reads
    // the live `bootReady` binding.
    function markWallpaperReady() {
        if (!root.startupWallpaperReady) {
            root.startupWallpaperReady = true
            root.advanceStartup(StartupReveal.Events.wallpaperReady)
        }
        root.mountChrome()
    }

    // The chrome finished staging. Recorded as a gate rather than a stage: the
    // ladder only leaves chrome-staging for the wave itself.
    function markChromeStaged() {
        if (root.startupChromeReady)
            return
        root.startupChromeReady = true
        root.advanceStartup(StartupReveal.Events.chromeReady)
    }

    // The lock committed to its entry wave: with motion it armed the bounded
    // image wait, under reduced motion it committed the settled state. Either
    // way that is the scheduling event, not an animation completion, and it is
    // what closes the ladder — so quiet-ready is set here, exactly once.
    function markStartupWaveStarted() {
        // The lock refuses to wave before both gates open, so this branch is
        // unreachable in a wired shell. It exists so an impossible wave still
        // leaves the ladder coherent instead of stranding quiet-ready.
        if (!root.startupWallpaperReady || !root.startupChromeReady)
            root.releaseStartupGates("wave-before-gates")
        root.advanceStartup(StartupReveal.Events.waveStarted)
        root.startupQuietReady = true
    }

    // Bounded fallback, so no boot can leave the session on an unlabelled static
    // floor. Every healthy boot reports on its own: a failed, empty, unchanged
    // or reduced-motion wallpaper still reports its outcome, and a screen that
    // appears late reports on arrival. What no path reports is a shell that
    // never gets one — no output at all, a chrome component that fails to
    // build, a bar that never finishes staging. This releases every gate so the
    // startup lock waves and post-startup work runs, and says so in the log.
    //
    // It only ever writes the root's own startup booleans: no request is made,
    // cancelled or reclassified, so a manual lock keeps the screenshot path it
    // has today, and the fallback cannot release the session lock.
    function releaseStartupGates(reason) {
        if (root.startupQuietReady) {
            console.warn("[startup] startup fallback fired after quiet-ready:", reason)
            return
        }
        root.startupFallbackUsed = true
        console.warn("[startup] startup gates released by the", reason, "fallback at stage",
                     root.startupStage)
        if (!root.startupWallpaperReady) {
            root.startupWallpaperReady = true
            root.advanceStartup(StartupReveal.Events.wallpaperReady)
        }
        root.mountChrome()
        if (!root.startupChromeReady) {
            root.startupChromeReady = true
            root.advanceStartup(StartupReveal.Events.chromeReady)
        }
        // With no output there is no lock surface, so nothing could ever report
        // the wave. Quiet-ready closes here instead of waiting for a signal that
        // cannot arrive; a screen that appears later mounts its chrome through
        // markWallpaperReady and its surface waves as soon as it is created.
        root.advanceStartup(StartupReveal.Events.waveStarted)
        root.startupQuietReady = true
    }

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

        // `bootReady` is a binding over the live screen list, so it flips again
        // on a re-key or a hotplug. The gate is latched instead: the startup
        // effects run once and the re-read changes nothing.
        onBootReadyChanged: {
            if (!bootReady || root.startupWallpaperReady)
                return
            root.markWallpaperReady()
        }
    }

    // The compositor-enforced session lock, one surface per screen. Mounted here
    // rather than in the chrome so the lock owns the `lock` IPC target from the
    // first turn: a keybind or `afloat-ipc lock` during bootstrap reaches the real
    // owner instead of a stand-in that has to queue and replay the request.
    LockModule.Lock {
        id: lockModule

        // The session-start wave waits for both gates. They are the root's own
        // latched startup state, so the lock never decides a boot outcome by
        // itself, and a manual request never consults them.
        startupWallpaperReady: root.startupWallpaperReady
        startupChromeReady: root.startupChromeReady
    }

    // The lock's committed-wave signal is the last stage event: post-startup
    // background work releases here, in parallel with the reveal rather than
    // after it.
    Connections {
        target: lockModule

        function onStartupWaveStarted() {
            root.markStartupWaveStarted()
        }
    }

    Loader {
        id: chromeLoader
        active: false
        sourceComponent: chromeComponent
        onStatusChanged: {
            // A chrome that cannot build is the same degraded boot: the gates
            // open and the session comes up without the surfaces that failed.
            if (status === Loader.Error) {
                root.releaseStartupGates("chrome-loader-error")
                return
            }
            // Read readiness directly instead of trusting the connection below
            // to fire: the item can already be staged by the time it attaches.
            if (chromeLoader.item && chromeLoader.item.startupReady === true)
                root.markChromeStaged()
        }
    }

    // The chrome reports its own readiness and the root only records it.
    // Targeting the loaded item keeps this alive across a remount without
    // polling, and a null target before the item exists is silent.
    Connections {
        target: chromeLoader.item

        function onStartupReadyChanged() {
            if (chromeLoader.item && chromeLoader.item.startupReady === true)
                root.markChromeStaged()
        }
    }

    // The bounded fallback's clock, armed at boot and stopped by quiet-ready.
    // Deliberately several times a healthy boot's cost: a normal session
    // reaches quiet-ready in about one wallpaper swap plus the staged frames.
    Timer {
        id: startupFallbackTimer
        interval: LazerBar.MotionTokens.slow * 10
        running: !root.startupQuietReady
        repeat: false
        onTriggered: root.releaseStartupGates("startup-watchdog")
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
            id: chromeRoot

            // Chrome readiness in two halves: the bar commits its geometry and
            // its fixed-outer surfaces first, then the auxiliary surfaces mount
            // once the bar's per-screen widget batches are done. A `Loader` adds
            // no layer-shell surface of its own — it only decides when an
            // existing component is created — so this reorders the build
            // without adding a surface, and the visual order below is unchanged.
            readonly property bool barStaged: topBar.startupReady === true
            property bool overviewReady: false
            property bool notificationsReady: false
            property bool cornersReady: false
            readonly property bool auxiliariesReady: chromeRoot.overviewReady
                    && chromeRoot.notificationsReady && chromeRoot.cornersReady
            readonly property bool startupReady: chromeRoot.barStaged
                    && chromeRoot.auxiliariesReady

            // Blurred/tinted wallpaper niri renders inside its overview backdrop.
            Loader {
                id: overviewLoader
                active: chromeRoot.barStaged
                sourceComponent: Component { LazerBar.OverviewBackgroundWindow {} }
                onStatusChanged: chromeRoot.reportAuxiliaryTerminal(overviewLoader, "overview")
            }

            // The layout-driven bar. Staging is a static true: a runtime toggle
            // would re-enter staging on a live bar and restage its widgets.
            Bar.TopBar {
                id: topBar
                startupStaging: true
            }

            Loader {
                id: notificationLoader
                active: chromeRoot.barStaged
                sourceComponent: Component { LazerBar.NotificationHost {} }
                onStatusChanged: chromeRoot.reportAuxiliaryTerminal(notificationLoader, "notifications")
            }

            // Fake rounded display corners. This surface paints only the corners
            // the bar does not physically cover: two overlay-layer surfaces
            // cannot be ordered against each other by the client, so the bar
            // paints its own corners from its own window. See TopBar.qml.
            Loader {
                id: cornerLoader
                active: chromeRoot.barStaged
                sourceComponent: Component { LazerBar.ScreenRoundedCorners {} }
                onStatusChanged: chromeRoot.reportAuxiliaryTerminal(cornerLoader, "corners")
            }

            // Terminal result for one auxiliary surface, by name. A loaded
            // surface is done; a failed one is done *with a warning*, because a
            // missing notification host is a visible gap while a startup lock
            // that never waves is an unusable session.
            function reportAuxiliaryTerminal(loader, name) {
                if (loader.status !== Loader.Ready && loader.status !== Loader.Error)
                    return
                if (loader.status === Loader.Error)
                    console.warn("[startup] chrome auxiliary surface could not load:", name,
                                 "- the startup lock is not held for it")
                chromeRoot.markAuxiliaryReady(name)
            }

            function markAuxiliaryReady(name) {
                if (name === "overview")
                    chromeRoot.overviewReady = true
                else if (name === "notifications")
                    chromeRoot.notificationsReady = true
                else if (name === "corners")
                    chromeRoot.cornersReady = true
            }

            // Bounded fallback for the same reason as the root's: a loader that
            // never leaves Loading is an engine stall rather than a component
            // error, and the surfaces still mount whenever they do load.
            function releaseAuxiliaries() {
                const pending = []
                if (!chromeRoot.overviewReady)
                    pending.push("overview")
                if (!chromeRoot.notificationsReady)
                    pending.push("notifications")
                if (!chromeRoot.cornersReady)
                    pending.push("corners")
                if (pending.length === 0)
                    return
                console.warn("[startup] releasing the auxiliary chrome gate for",
                             pending.join(", "))
                chromeRoot.overviewReady = true
                chromeRoot.notificationsReady = true
                chromeRoot.cornersReady = true
            }

            Timer {
                id: auxiliaryFallbackTimer
                interval: LazerBar.MotionTokens.slow * 2
                running: chromeRoot.barStaged && !chromeRoot.auxiliariesReady
                repeat: false
                onTriggered: chromeRoot.releaseAuxiliaries()
            }

            // Defer external app-theme work until the chrome has yielded a few
            // frames. gsettings, KDE/Niri sync, and template rendering are not
            // part of the shell's first-paint path and can otherwise compete
            // with the just-finished wallpaper transition. Launcher, clipboard
            // and hint warmup used to sit here too; they now run after the
            // startup wave, one event-loop turn apart.
            Timer {
                interval: LazerBar.MotionTokens.slow * 5
                repeat: false
                running: true
                onTriggered: {
                    Services.AppThemeService.apply()
                    Services.AppThemeService.pushSystemTheme()
                }
            }
        }
    }
}
