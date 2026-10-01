import QtQuick
import Quickshell
import Quickshell.Io

// Regression harness for the startup order: the session lock is the session's
// first screen, so it engages from the bootstrap layer while the wallpaper
// reveal and the chrome still build behind it, and the lock's entry wave waits
// for both startup gates. This reads shell.qml as text and checks the ordering
// contract directly — the components involved (`LockModule.Lock`,
// `WlSessionLock`) cannot be instantiated headlessly, since offscreen has no
// session-lock backend.
//
// Run from the repo root so ./services resolves inside the config folder:
//   qs -p tst_lock_startup_order.qml
Item {
    id: root

    property int failures: 0
    property int checks: 0
    property string source: ""
    property string ladder: ""
    property bool shellLoaded: false
    property bool ladderLoaded: false
    readonly property bool sourcesReady: root.shellLoaded && root.ladderLoaded

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
            root.shellLoaded = true
            root.run()
        }
        onLoadFailed: error => {
            console.log("FAIL: read shell.qml |", error)
            root.failures++
            Qt.quit()
        }
    }

    // The stage ladder the root delegates to. The root consumes this file's
    // exported event constants, so the canonical names have to exist here and
    // have to be the ones the root stages on — otherwise the root could advance
    // on strings the ladder never defined, which silently does nothing.
    FileView {
        id: ladderSource
        path: (Quickshell.env("PWD") || ".") + "/modules/lazerbar/StartupRevealLogic.js"
        blockLoading: true
        watchChanges: false
        onLoaded: {
            root.ladder = ladderSource.text()
            root.ladderLoaded = true
            root.run()
        }
        onLoadFailed: error => {
            console.log("FAIL: read StartupRevealLogic.js |", error)
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

    function indexFrom(needle, from) {
        return root.source.indexOf(needle, from < 0 ? 0 : from)
    }

    // Count non-overlapping occurrences, so "three auxiliary loaders" is
    // asserted as three and not as one.
    function countOccurrences(needle) {
        if (!needle)
            return 0
        var total = 0
        var at = root.source.indexOf(needle)
        while (at >= 0) {
            total++
            at = root.source.indexOf(needle, at + needle.length)
        }
        return total
    }

    // Index of the chrome component's own declaration, found by its id rather
    // than by matching surrounding whitespace.
    readonly property int chromeStart: root.source.indexOf("id: chromeComponent")

    // The chrome component is the last member of the root, so its body ends at
    // the file's final brace. Bounding the lookup by that keeps a member
    // declared after the chrome component from counting as part of it.
    readonly property int chromeEnd: root.source.lastIndexOf("}")

    // Position of a member's declaration inside the chrome component body, so a
    // member named in a comment or in the bootstrap layer does not count.
    function positionInChrome(needle) {
        if (root.chromeStart < 0)
            return -1
        const at = root.source.indexOf(needle, root.chromeStart)
        if (at < 0 || at > root.chromeEnd)
            return -1
        return at
    }

    // Body of one root function, from its declaration to the brace that closes
    // it at the same indentation, so a check can read what a single callback
    // does instead of the whole file.
    function bodyOf(declaration) {
        const start = root.source.indexOf(declaration)
        if (start < 0)
            return ""
        const end = root.source.indexOf("\n    }", start)
        if (end < 0)
            return root.source.slice(start)
        return root.source.slice(start, end)
    }

    // Collapsed to single spaces, so a multi-line expression can be asserted as
    // one literal while still being indifferent to how it is wrapped.
    function normalized(text) {
        return String(text || "").replace(/\s+/g, " ")
    }

    // Index of the brace that balances the one at `open`, counting literally:
    // a stray brace inside a string or a comment would shift the result, so
    // every caller also asserts what its block actually starts with.
    function closingBraceAt(open) {
        let depth = 0
        for (let at = open; at < root.source.length; at++) {
            const character = root.source.charAt(at)
            if (character === "{")
                depth++
            else if (character === "}") {
                depth--
                if (depth === 0)
                    return at
            }
        }
        return root.source.length - 1
    }

    // The block an opener introduces, for a marker that names the object itself
    // ("Bar.TopBar {").
    function blockFrom(opener) {
        const start = root.source.indexOf(opener)
        if (start < 0)
            return ""
        const open = root.source.indexOf("{", start)
        if (open < 0)
            return ""
        return root.source.slice(start, root.closingBraceAt(open) + 1)
    }

    // The object a member declaration lives in, for a marker that is *inside* the
    // block ("id: lockModule"). Walking backwards, the first `{` that no passed
    // `}` already claims is the one that opens the object the marker sits in.
    // Scoping a check to a block is what keeps a *sibling's* member from
    // satisfying a check written for this one.
    //
    // The marker must therefore name a member, never the object's own opener
    // ("Bar.TopBar {"): that brace sits after the match and would be stepped
    // over, handing back the enclosing object instead. Use blockFrom for those.
    function enclosingBlock(member) {
        const start = root.source.indexOf(member)
        if (start < 0)
            return ""
        let depth = 0
        for (let at = start - 1; at >= 0; at--) {
            const character = root.source.charAt(at)
            if (character === "}")
                depth++
            else if (character === "{") {
                if (depth === 0)
                    return root.source.slice(at, root.closingBraceAt(at) + 1)
                depth--
            }
        }
        return ""
    }

    function run() {
        // Every check below reads positions in these files, so an unreadable or
        // truncated source must fail loudly rather than pass on empty strings.
        if (!root.sourcesReady)
            return
        if (root.source.length < 500) {
            console.log("FAIL: shell.qml was not readable |", root.source.length, "chars")
            Qt.quit()
            return
        }
        if (root.ladder.length < 200) {
            console.log("FAIL: StartupRevealLogic.js was not readable |",
                        root.ladder.length, "chars")
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
        const barAt = root.positionInChrome("Bar.TopBar {")
        root.check("wallpaper is still the first visual surface",
                   wallpaperAt >= 0 && barAt >= 0 && wallpaperAt < barAt)
        root.check("chrome still waits for boot readiness",
                   root.indexOf("onBootReadyChanged") >= 0
                   && root.indexOf("if (!bootReady || root.startupWallpaperReady)") >= 0,
                   "bootReady handler at " + root.indexOf("onBootReadyChanged"))

        root.checkStartupState()
        root.checkStageLadder()
        root.checkRootLockBindings()
        root.checkChromeStaging()
        root.checkFallback()
        root.checkDeferredWarmup()

        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }

    // The root owns the ladder state: three readiness gates plus the stage they
    // climb, all declared at the root (before the chrome component) and all
    // starting closed, so a boot that reports nothing leaves the lock shut.
    function checkStartupState() {
        const declarations = [
            "property int startupStage: StartupReveal.Stages.lockedFloor",
            "property bool startupWallpaperReady: false",
            "property bool startupChromeReady: false",
            "property bool startupQuietReady: false",
        ]
        for (let index = 0; index < declarations.length; index++) {
            const declaration = declarations[index]
            const at = root.indexOf(declaration)
            root.check("root declares " + declaration.split(":")[0].trim(),
                       at >= 0 && at < root.chromeStart, "declared at " + at)
        }

        // A shared readiness boolean must not stand in for the mount latch: the
        // fallback can open the gates before any screen exists, and a screen
        // that arrives later still has to get its chrome.
        root.check("chrome mount has its own one-way latch",
                   root.indexOf("property bool _chromeMounted: false") >= 0
                   && root.bodyOf("function mountChrome()").indexOf(
                          "if (root._chromeMounted)") >= 0)

        // Quiet-ready has exactly two writers: the lock's committed wave, and
        // the bounded fallback. A third — reaching it off an earlier gate —
        // would release post-startup work before the first screen finished.
        const writers = root.countOccurrences("root.startupQuietReady = true")
        root.check("quiet-ready is written only by the wave and the fallback",
                   writers === 2
                   && root.bodyOf("function markStartupWaveStarted()").indexOf(
                          "root.startupQuietReady = true") >= 0
                   && root.bodyOf("function releaseStartupGates(reason)").indexOf(
                          "root.startupQuietReady = true") >= 0,
                   "writers: " + writers)
    }

    // `advanceStartup` delegates to the ladder and writes back only a real
    // step, and every stage event comes from the ladder's own exported table.
    function checkStageLadder() {
        const body = root.bodyOf("function advanceStartup(event)")
        root.check("root advances the stage through the shared logic",
                   root.indexOf("function advanceStartup(event)") >= 0
                   && root.indexOf("function advanceStartup(event)") < root.chromeStart
                   && body.indexOf("StartupReveal.advance(root.startupStage, event)") >= 0
                   && body.indexOf("if (next === root.startupStage)") >= 0
                   && body.indexOf("root.startupStage = next") >= 0,
                   "body: " + root.normalized(body).slice(0, 160))

        const pairs = [
            ["wallpaperReady", "wallpaper-ready"],
            ["chromeMounted", "chrome-mounted"],
            ["chromeReady", "chrome-ready"],
            ["waveStarted", "wave-started"],
        ]
        for (let index = 0; index < pairs.length; index++) {
            const constant = "StartupReveal.Events." + pairs[index][0]
            const canonical = pairs[index][1]
            root.check("root stages on the ladder's " + constant + " (\"" + canonical + "\")",
                       root.indexOf(constant) >= 0
                       && root.ladder.indexOf('"' + canonical + '"') >= 0,
                       "constant at " + root.indexOf(constant) + ", canonical name at "
                           + root.ladder.indexOf('"' + canonical + '"'))
        }
    }

    // Both startup gates reach the lock as bindings on the root's own state, so
    // the lock never decides a boot outcome by itself. Scoped to the lock's own
    // block: a binding written on some later surface must not count as the lock
    // being gated.
    function checkRootLockBindings() {
        const lockBlock = root.normalized(
            root.enclosingBlock("id: lockModule"))
        root.check("lock reads the root wallpaper gate",
                   root.indexOf("LockModule.Lock {") >= 0
                   && lockBlock.indexOf("{ id: lockModule") === 0
                   && lockBlock.indexOf(
                          "startupWallpaperReady: root.startupWallpaperReady") >= 0,
                   "lock: " + lockBlock.slice(0, 160))
        root.check("lock reads the root chrome gate",
                   lockBlock.indexOf("startupChromeReady: root.startupChromeReady") >= 0)

        // The startup request itself must stay at the root, and never appear
        // inside the chrome: a request made from there could only engage after
        // the wallpaper reveal.
        root.check("the startup request stays outside the chrome",
                   root.positionInChrome("startupLock()") < 0
                   && root.indexOf("lockModule.startupLock()") < root.chromeStart)

        // Quiet-ready is the wave, so the lock's own scheduling signal is what
        // closes the last stage. Waiting on anything else (palette extraction,
        // launcher priming) is exactly what this ladder exists to avoid.
        const waveBody = root.bodyOf("function markStartupWaveStarted()")
        root.check("the lock's wave signal closes the startup ladder",
                   root.indexOf("function onStartupWaveStarted()") >= 0
                   && waveBody.indexOf("StartupReveal.Events.waveStarted") >= 0
                   && waveBody.indexOf("root.startupQuietReady = true") >= 0,
                   "body: " + root.normalized(waveBody).slice(0, 160))
    }

    // The chrome reports readiness only after the bar staged its widgets and the
    // auxiliary surfaces mounted; the bar is told to stage statically, and the
    // auxiliary surfaces are Loaders gated on that staging.
    function checkChromeStaging() {
        const barBlock = root.blockFrom("Bar.TopBar {")
        root.check("top bar is staged at startup",
                   root.positionInChrome("Bar.TopBar {") >= 0
                   && root.normalized(barBlock).indexOf("startupStaging: true") >= 0,
                   "bar: " + root.normalized(barBlock).slice(0, 120))
        // A runtime toggle would re-enter staging and re-stage live widgets.
        root.check("startup staging is never toggled back off",
                   root.indexOf("startupStaging: false") < 0)

        // Whitespace-collapsed, because a readiness expression that drops one of
        // its two operands must fail: a gate on the auxiliaries alone would let
        // the wave start before the bar staged.
        const chromeText = root.normalized(
            root.source.slice(root.chromeStart, root.chromeEnd))
        root.check("chrome readiness waits for the bar and the auxiliary loaders",
                   root.positionInChrome("readonly property bool startupReady:") >= 0
                   && chromeText.indexOf("readonly property bool startupReady: "
                       + "chromeRoot.barStaged && chromeRoot.auxiliariesReady") >= 0
                   && chromeText.indexOf("readonly property bool barStaged: "
                       + "topBar.startupReady === true") >= 0,
                   "chrome: " + root.normalized(
                       root.positionInChrome("readonly property bool startupReady:")
                           ? root.source.slice(root.positionInChrome(
                                 "readonly property bool startupReady:"), root.chromeEnd)
                           : "").slice(0, 200))
        root.check("the auxiliary gate needs all three surfaces",
                   chromeText.indexOf("readonly property bool auxiliariesReady: "
                       + "chromeRoot.overviewReady && chromeRoot.notificationsReady "
                       + "&& chromeRoot.cornersReady") >= 0)

        const auxiliaries = [
            ["LazerBar.OverviewBackgroundWindow {}", "overviewLoader", "overviewReady"],
            ["LazerBar.NotificationHost {}", "notificationLoader", "notificationsReady"],
            ["LazerBar.ScreenRoundedCorners {}", "cornerLoader", "cornersReady"],
        ]
        for (let index = 0; index < auxiliaries.length; index++) {
            const component = auxiliaries[index][0]
            const loader = auxiliaries[index][1]
            const flag = auxiliaries[index][2]
            // Scoped to the loader's own block: a sibling's `active:` must not
            // satisfy the check written for this one, or an ungated loader that
            // mounts in the first frame goes unnoticed.
            const block = root.normalized(root.enclosingBlock("id: " + loader))
            root.check(loader + " is a gated loader for " + component,
                       root.positionInChrome("id: " + loader) >= 0
                       && block.indexOf("{ id: " + loader) === 0
                       && block.indexOf(component) >= 0
                       && block.indexOf("active: chromeRoot.barStaged") >= 0
                       && block.indexOf("chromeRoot.reportAuxiliaryTerminal(") >= 0
                       && root.positionInChrome("property bool " + flag + ": false") >= 0,
                       "block: " + block.slice(0, 160))
        }

        // Terminal readiness per loader: a failed surface releases its gate with
        // a warning instead of parking the startup lock on its floor.
        root.check("every auxiliary loader has a terminal readiness marker",
                   root.positionInChrome("reportAuxiliaryTerminal") >= 0
                   && root.countOccurrences("chromeRoot.reportAuxiliaryTerminal(") === 3
                   && root.positionInChrome("Loader.Error") >= 0
                   && root.positionInChrome("console.warn") >= 0,
                   "reports: " + root.countOccurrences("chromeRoot.reportAuxiliaryTerminal("))

        // A loader that never leaves Loading is an engine stall rather than a
        // component error, so the gate is bounded too. Scoped to the timer's own
        // block: the app-theme timer further down must not vouch for it.
        const auxTimer = root.normalized(root.enclosingBlock("id: auxiliaryFallbackTimer"))
        root.check("auxiliary staging is bounded",
                   root.positionInChrome("id: auxiliaryFallbackTimer") >= 0
                   && auxTimer.indexOf("{ id: auxiliaryFallbackTimer") === 0
                   && auxTimer.indexOf("repeat: false") >= 0
                   && auxTimer.indexOf("LazerBar.MotionTokens.slow") >= 0
                   && auxTimer.indexOf("chromeRoot.releaseAuxiliaries()") >= 0,
                   "timer: " + auxTimer.slice(0, 160))
    }

    // The root's own watchdog: it releases every gate, logs the reason, and
    // touches nothing about locking. A manual request must keep its existing
    // screenshot-and-wave path, and the fallback must not reclassify one.
    function checkFallback() {
        const body = root.bodyOf("function releaseStartupGates(reason)")
        const released = ["root.startupWallpaperReady = true", "root.mountChrome()",
                          "root.startupChromeReady = true", "root.startupQuietReady = true",
                          "console.warn", "StartupReveal.Events.waveStarted"]
        let missing = []
        for (let index = 0; index < released.length; index++) {
            if (body.indexOf(released[index]) < 0)
                missing.push(released[index])
        }
        root.check("the bounded fallback releases every startup gate",
                   body.length > 0 && missing.length === 0,
                   "missing: " + missing.join(", "))

        // The fallback may only write the root's startup booleans: no request is
        // made, cancelled or reclassified by it.
        const lockCalls = ["startupLock()", ".lock(", "requestSessionLock()", "unlock()",
                           "startupRequest", "backgroundMode"]
        let crossed = []
        for (let index = 0; index < lockCalls.length; index++) {
            if (body.indexOf(lockCalls[index]) >= 0)
                crossed.push(lockCalls[index])
        }
        root.check("the fallback never touches lock behaviour",
                   body.length > 0 && crossed.length === 0,
                   "found: " + crossed.join(", "))

        const watchdog = root.normalized(root.enclosingBlock("id: startupFallbackTimer"))
        root.check("the root watchdog is bounded and one-shot",
                   root.indexOf("id: startupFallbackTimer") >= 0
                   && root.indexOf("id: startupFallbackTimer") < root.chromeStart
                   && watchdog.indexOf("{ id: startupFallbackTimer") === 0
                   && watchdog.indexOf("repeat: false") >= 0
                   && watchdog.indexOf("running: !root.startupQuietReady") >= 0
                   && watchdog.indexOf("LazerBar.MotionTokens.slow") >= 0
                   && watchdog.indexOf("root.releaseStartupGates(") >= 0,
                   "watchdog: " + watchdog.slice(0, 160))

        // A chrome that cannot build is the same degraded boot: the gates open
        // instead of the session waiting on a loader that already failed.
        const loaderBlock = root.normalized(root.enclosingBlock("id: chromeLoader"))
        root.check("a failed chrome loader releases the gates",
                   root.indexOf("id: chromeLoader") >= 0
                   && loaderBlock.indexOf("{ id: chromeLoader") === 0
                   && loaderBlock.indexOf("Loader.Error") >= 0
                   && loaderBlock.indexOf("root.releaseStartupGates(") >= 0,
                   "loader: " + loaderBlock.slice(0, 160))

        // The chrome mounts once and is never torn down, so a screen re-key or
        // a hotplug cannot remount every surface.
        root.check("chrome is activated once and never deactivated",
                   root.countOccurrences("chromeLoader.active = true") >= 1
                   && root.indexOf("chromeLoader.active = false") < 0)
    }

    // Warmups left the chrome's completion callback: they run after the startup
    // wave, one event-loop turn apart, so they cannot occupy the first-paint
    // path. The delayed external-theme work stays exactly where it was.
    function checkDeferredWarmup() {
        const warmups = ["Services.LauncherService.primeApps()",
                         "Services.ClipboardService.warmup()",
                         "Services.WindowHintService.hintHeld"]
        for (let index = 0; index < warmups.length; index++) {
            root.check("chrome completion no longer calls " + warmups[index],
                       root.positionInChrome(warmups[index]) < 0,
                       "found in chrome at " + root.positionInChrome(warmups[index]))
        }

        root.check("external app theme keeps its delayed timer",
                   root.positionInChrome("Services.AppThemeService.apply()") >= 0
                   && root.positionInChrome("LazerBar.MotionTokens.slow * 5") >= 0)
    }
}
