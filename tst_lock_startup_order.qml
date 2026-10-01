import QtQuick
import Quickshell
import Quickshell.Io

// Regression harness for the startup order: the session lock is the session's
// first screen, so it engages from the bootstrap layer while the wallpaper
// reveal and the chrome still build behind it. This reads shell.qml as text and
// checks the ordering contract directly — the components involved
// (`LockModule.Lock`, `WlSessionLock`) cannot be instantiated headlessly, since
// offscreen has no session-lock backend.
//
// Run from the repo root so ./services resolves inside the config folder:
//   qs -p tst_lock_startup_order.qml
Item {
    id: root

    property int failures: 0
    property int checks: 0
    property string source: ""

    // Read the shell as text. The components whose order matters here cannot be
    // instantiated headlessly: `WlSessionLock` has no offscreen backend, so
    // asserting on the declaration order is the only honest check available.
    FileView {
        id: shellSource
        // Absolute, because a root harness' own location is not what FileView
        // resolves against; the runner always starts from the repo root.
        path: (Quickshell.env("PWD") || ".") + "/shell.qml"
        blockLoading: true
        watchChanges: false
        onLoaded: {
            root.source = shellSource.text()
            root.run()
        }
        onLoadFailed: error => {
            console.log("FAIL: read shell.qml |", error)
            root.failures++
            Qt.quit()
        }
    }

    function check(label, condition, detail) {
        root.checks++
        if (condition) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, detail !== undefined ? "| " + detail : "")
    }

    function indexOf(needle) {
        return root.source.indexOf(needle)
    }

    // Index of the chrome component's own declaration, found by its id rather
    // than by matching surrounding whitespace.
    readonly property int chromeStart: root.source.indexOf("id: chromeComponent")

    // Position of a member's declaration inside the chrome component body, so a
    // member named in a comment or in the bootstrap layer does not count.
    function positionInChrome(needle) {
        if (root.chromeStart < 0)
            return -1
        return root.source.indexOf(needle, root.chromeStart)
    }

    function run() {
        // Every check below reads positions in this file, so an unreadable or
        // truncated source must fail loudly rather than pass on empty strings.
        if (root.source.length < 500) {
            console.log("FAIL: shell.qml was not readable |", root.source.length, "chars")
            Qt.quit()
            return
        }

        // The lock must not be part of the lazily mounted chrome: a lock inside
        // it can only engage after the wallpaper reveal, which is exactly the
        // half-assembled-desktop screenshot this replaces.
        root.check("lock is not inside the chrome component",
                   root.positionInChrome("LockModule.Lock {") < 0,
                   "chrome found at " + root.chromeStart + ", lock in chrome at "
                        + root.positionInChrome("LockModule.Lock {"))

        // It must be mounted eagerly at the root instead.
        root.check("lock is mounted at the shell root",
                   root.indexOf("LockModule.Lock {") >= 0,
                   "declared at " + root.indexOf("LockModule.Lock {"))

        // The startup request comes from the root completion, not from chrome.
        root.check("startup lock is requested from the root",
                   root.indexOf("lockModule.startupLock()") >= 0
                   && root.indexOf("lockModule.startupLock()") < root.chromeStart,
                   "startupLock at " + root.indexOf("lockModule.startupLock()")
                        + ", chrome at " + root.chromeStart)

        // The bootstrap IPC bridge existed only to stand in for a lock that did
        // not exist yet. With the lock mounted eagerly there is nothing to
        // stand in for, and two handlers on one target is a Quickshell warning.
        root.check("bootstrap lock bridge is gone",
                   root.indexOf("bootstrapLockBridge") < 0
                   && root.indexOf("queuedLockRequest") < 0
                   && root.indexOf("adoptLockOwner") < 0)

        // The wallpaper still leads: it stays the first visual surface, and the
        // chrome still waits for boot readiness, so the desktop is settled
        // behind the lock by the time the user authenticates.
        const wallpaperAt = root.indexOf("LazerBar.WallpaperBackground {")
        const barAt = root.indexOf("Bar.TopBar {}")
        root.check("wallpaper is still the first visual surface",
                   wallpaperAt >= 0 && wallpaperAt < barAt)
        root.check("chrome still waits for boot readiness",
                   root.indexOf("if (!bootReady || chromeLoader.active)") >= 0)

        // Desktop warmup belongs to the chrome, where it builds behind the lock.
        const warmupAt = root.indexOf("Services.LauncherService.primeApps()")
        root.check("desktop warmup still runs in the chrome",
                   warmupAt > root.chromeStart && root.chromeStart >= 0,
                   "warmup at " + warmupAt + ", chrome at " + root.chromeStart)

        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }
}
