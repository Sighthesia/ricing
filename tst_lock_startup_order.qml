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
    property string lock: ""
    property bool shellLoaded: false
    property bool ladderLoaded: false
    property bool lockLoaded: false
    readonly property bool sourcesReady: root.shellLoaded && root.ladderLoaded
            && root.lockLoaded

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

    // The lock itself, for the one verdict the root needs from it: whether a
    // session-start lock is still expected. Read as text for the same reason as
    // shell.qml — `WlSessionLock` has no offscreen backend, so the property's
    // wiring is the only honest check available here.
    FileView {
        id: lockSource
        path: (Quickshell.env("PWD") || ".") + "/modules/lock/Lock.qml"
        blockLoading: true
        watchChanges: false
        onLoaded: {
            root.lock = lockSource.text()
            root.lockLoaded = true
            root.run()
        }
        onLoadFailed: error => {
            console.log("FAIL: read Lock.qml |", error)
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

    // Count non-overlapping occurrences of `needle` inside `haystack`, so a
    // per-block assertion ("this timer stops twice") cannot be satisfied by
    // another object's copy.
    function countOccurrencesIn(haystack, needle) {
        if (!needle || !haystack)
            return 0
        var total = 0
        var at = haystack.indexOf(needle)
        while (at >= 0) {
            total++
            at = haystack.indexOf(needle, at + needle.length)
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

    // End of the statement that starts at `at`: the next blank line, the next
    // member-level comment, or a bounded fallback. Used to read one declaration
    // instead of the file that contains it.
    function statementEnd(text, at) {
        const blank = text.indexOf("\n\n", at)
        const comment = text.indexOf("\n    //", at)
        let end = -1
        if (blank >= 0)
            end = blank
        if (comment >= 0 && (end < 0 || comment < end))
            end = comment
        return end < 0 ? Math.min(text.length, at + 240) : end
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
        if (root.lock.length < 500) {
            console.log("FAIL: Lock.qml was not readable |", root.lock.length, "chars")
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
        root.checkReportingPath()
        root.checkRootLockBindings()
        root.checkLockExpectation()
        root.checkChromeStaging()
        root.checkFallback()
        root.checkDeferredWarmup()
        root.checkStartupTaskQueue()

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

    // The reporting path itself, not just the names of its parts: each report
    // has to arrive from the handler that owns it, and each has to actually
    // write the gate it claims to. Presence checks alone let a deleted call site
    // pass, which is how a root can declare a coordinator that nothing drives.
    function checkReportingPath() {
        // The wallpaper's handler must reach the coordinator, behind its latch.
        const wallpaperBlock = root.normalized(root.enclosingBlock("id: wallpaperBackground"))
        root.check("the wallpaper report reaches the coordinator",
                   wallpaperBlock.indexOf("{ id: wallpaperBackground") === 0
                   && wallpaperBlock.indexOf("onBootReadyChanged") >= 0
                   && wallpaperBlock.indexOf(
                          "if (!bootReady || root.startupWallpaperReady)") >= 0
                   && wallpaperBlock.indexOf("root.markWallpaperReady()") >= 0,
                   "wallpaper: " + wallpaperBlock.slice(0, 160))

        const wallpaperBody = root.normalized(root.bodyOf("function markWallpaperReady()"))
        root.check("the wallpaper gate is written and mounts the chrome",
                   wallpaperBody.indexOf("root.startupWallpaperReady = true") >= 0
                   && wallpaperBody.indexOf("root.mountChrome()") >= 0
                   && wallpaperBody.indexOf(
                          "StartupReveal.Events.wallpaperReady") >= 0,
                   "body: " + wallpaperBody.slice(0, 160))

        // Both chrome paths must report: the loader's own status change (which
        // covers a chrome that is already staged when the item attaches) and the
        // item's readiness change. Either one alone leaves a boot unstaged.
        const loaderBlock = root.normalized(root.enclosingBlock("id: chromeLoader"))
        root.check("the chrome loader reports its own staged chrome",
                   loaderBlock.indexOf("{ id: chromeLoader") === 0
                   && loaderBlock.indexOf("onStatusChanged") >= 0
                   && loaderBlock.indexOf("root.markChromeStaged()") >= 0,
                   "loader: " + loaderBlock.slice(0, 200))
        const itemBlock = root.normalized(
            root.enclosingBlock("target: chromeLoader.item"))
        root.check("the loaded chrome reports its readiness",
                   itemBlock.indexOf("target: chromeLoader.item") >= 0
                   && itemBlock.indexOf("function onStartupReadyChanged()") >= 0
                   && itemBlock.indexOf("root.markChromeStaged()") >= 0,
                   "item: " + itemBlock.slice(0, 200))

        // A recorded gate has to be a write, not a stage bump on its own.
        const stagedBody = root.normalized(root.bodyOf("function markChromeStaged()"))
        root.check("the chrome gate is written, not only staged",
                   stagedBody.indexOf("root.startupChromeReady = true") >= 0
                   && stagedBody.indexOf("StartupReveal.Events.chromeReady") >= 0,
                   "body: " + stagedBody.slice(0, 160))

        // The wave arrives from the lock's signal, through the root's handler.
        const waveBlock = root.normalized(root.enclosingBlock("target: lockModule"))
        root.check("the lock's wave signal reaches the root handler",
                   waveBlock.indexOf("target: lockModule") >= 0
                   && waveBlock.indexOf("function onStartupWaveStarted()") >= 0
                   && waveBlock.indexOf("root.markStartupWaveStarted()") >= 0,
                   "wave: " + waveBlock.slice(0, 160))

        // Progress must extend the watchdog's budget instead of spending it: a
        // slow decode, then the bar's batches, each get the full window.
        const advanceBody = root.normalized(root.bodyOf("function advanceStartup(event)"))
        const armBody = root.normalized(root.bodyOf("function armStartupFallback()"))
        root.check("ladder progress re-arms the fallback watchdog",
                   advanceBody.indexOf("root.armStartupFallback()") >= 0
                   && armBody.indexOf("startupFallbackTimer.restart()") >= 0
                   && wallpaperBody.indexOf("root.armStartupFallback()") >= 0,
                   "advance: " + advanceBody.slice(0, 160) + " arm: " + armBody.slice(0, 160))
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
        const waveBody = root.normalized(root.bodyOf("function markStartupWaveStarted()"))
        root.check("the lock's wave signal closes the startup ladder",
                   waveBody.indexOf("StartupReveal.Events.waveStarted") >= 0
                   && waveBody.indexOf("root.startupQuietReady = true") >= 0
                   && waveBody.indexOf("startupFallbackTimer.stop()") >= 0,
                   "body: " + waveBody.slice(0, 160))
    }

    // The lock states whether a session-start lock is still to be expected, and
    // that verdict — not a timer — decides whether the root arms its fallback.
    // Without it, a reload inside a session whose marker was already spent would
    // fire the watchdog 2.4 s later and record a degraded boot that never
    // happened. Read Lock.qml as text for the same reason as shell.qml.
    function checkLockExpectation() {
        const declaration = "readonly property bool startupLockExpected:"
        const at = root.lock.indexOf(declaration)
        root.check("lock publishes a startup expectation",
                   at >= 0, "declared at " + at)
        if (at < 0)
            return

        // Its expression, pinned whole: the unresolved marker, an accepted
        // startup request, and an attempt that is still armed — and nothing else.
        // An extra term would make a spent session look expected again, which is
        // the exact false degraded boot this verdict exists to prevent, so the
        // text is asserted rather than merely probed for its three operands.
        const text = root.normalized(
            root.lock.slice(at, statementEnd(root.lock, at)))
        root.check("the expectation is exactly marker, request or armed attempt",
                   text === "readonly property bool startupLockExpected: "
                       + "!_startupGateResolved || startupRequest || _startupLockArmed",
                   "declaration: " + text.slice(0, 200))

        // The root consumes the verdict when arming, and stands the watchdog
        // down when it flips false — a reload must not record a degraded boot.
        const armBody = root.normalized(root.bodyOf("function armStartupFallback()"))
        root.check("every watchdog arm is gated on the lock's expectation",
                   armBody.indexOf("if (root.startupQuietReady "
                       + "|| !lockModule.startupLockExpected) return") >= 0
                   && armBody.indexOf("startupFallbackTimer.restart()") >= 0,
                   "arm: " + armBody.slice(0, 200))
        const expectBlock = root.normalized(
            root.enclosingBlock("function onStartupLockExpectedChanged()"))
        root.check("a spent marker stands the watchdog down",
                   expectBlock.indexOf("function onStartupLockExpectedChanged()") >= 0
                   && expectBlock.indexOf("!lockModule.startupLockExpected") >= 0
                   && expectBlock.indexOf("startupFallbackTimer.stop()") >= 0,
                   "expectation: " + expectBlock.slice(0, 200))
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
        // block and to its exact budget: the app-theme timer further down must
        // not vouch for it, and a shorter budget would cut the bar's batches off.
        const auxTimer = root.normalized(root.enclosingBlock("id: auxiliaryFallbackTimer"))
        root.check("auxiliary staging is bounded",
                   root.positionInChrome("id: auxiliaryFallbackTimer") >= 0
                   && auxTimer.indexOf("{ id: auxiliaryFallbackTimer") === 0
                   && auxTimer.indexOf("interval: LazerBar.MotionTokens.slow * 2") >= 0
                   && auxTimer.indexOf("running: chromeRoot.barStaged "
                       + "&& !chromeRoot.auxiliariesReady") >= 0
                   && auxTimer.indexOf("repeat: false") >= 0
                   && auxTimer.indexOf("chromeRoot.releaseAuxiliaries()") >= 0,
                   "timer: " + auxTimer.slice(0, 200))
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
        // The fallback stops the watchdog on the way in and on the way out: the
        // ladder events inside it re-arm the very watchdog that is firing, so a
        // version that only stopped on entry would leave a second one pending
        // and log itself a false degraded boot 2.4 s later.
        const quietAt = body.indexOf("root.startupQuietReady = true")
        const stops = root.countOccurrencesIn(body, "startupFallbackTimer.stop()")
        root.check("the bounded fallback releases every startup gate",
                   body.length > 0 && missing.length === 0
                   && stops === 2
                   && body.lastIndexOf("startupFallbackTimer.stop()") > quietAt
                   && body.indexOf("startupFallbackTimer.stop()") < body.indexOf(
                          "if (root.startupQuietReady)"),
                   "missing: " + missing.join(", ") + ", stops: " + stops)

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
                   // The exact budget: long enough for a slow decode plus the
                   // bar's batches, and token-derived so a retune stays visible.
                   && watchdog.indexOf("interval: LazerBar.MotionTokens.slow * 10") >= 0
                   // `running` carries only the stop conditions, so the startup
                   // expectation is a gate and never a restart trigger; the
                   // starter timer below is what arms it.
                   && watchdog.indexOf("running: false") >= 0
                   && watchdog.indexOf("repeat: false") >= 0
                   && watchdog.indexOf("root.releaseStartupGates(") >= 0,
                   "watchdog: " + watchdog.slice(0, 220))

        // Arming is explicit and happens in exactly two ways: one turn after the root
        // exists, and every ladder step. A watchdog that only starts itself would
        // measure time since construction and cut a slow decode's successors short.
        const restarts = root.countOccurrences("startupFallbackTimer.restart()")
        const starter = root.normalized(
            root.enclosingBlock("onTriggered: root.armStartupFallback()"))
        root.check("the watchdog is armed explicitly, once per progress step",
                   restarts === 1
                   && root.countOccurrences("root.armStartupFallback()") >= 3
                   && starter.indexOf("onTriggered: root.armStartupFallback()") >= 0
                   && starter.indexOf("interval: 0") >= 0
                   && starter.indexOf("running: true") >= 0
                   && starter.indexOf("repeat: false") >= 0,
                   "restarts: " + restarts + ", starter: " + starter.slice(0, 160))

        // A chrome that cannot build is the same degraded boot: the gates open
        // instead of the session waiting on a loader that already failed.
        const loaderBlock = root.normalized(root.enclosingBlock("id: chromeLoader"))
        root.check("a failed chrome loader releases the gates",
                   root.indexOf("id: chromeLoader") >= 0
                   && loaderBlock.indexOf("{ id: chromeLoader") === 0
                   && loaderBlock.indexOf("Loader.Error") >= 0
                   && loaderBlock.indexOf("root.releaseStartupGates(") >= 0,
                   "loader: " + loaderBlock.slice(0, 200))

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

    // The root's deferred startup queue. Its whole reason to exist is that these
    // three warmups left the chrome, so the checks here are about the wiring that
    // replaced them: one task per tick, the palette gate and the pulse unmute at
    // the end, and a queue that still opens on a reload which has no startup wave
    // to wait for.
    function checkStartupTaskQueue() {
        const body = root.normalized(root.bodyOf("function runStartupTask(index)"))
        // The three tasks, in this order, and one index per task. An order change
        // or a dropped index would either move the launcher scan behind the
        // clipboard load or run a task twice.
        const prime = "index === 0) Services.LauncherService.primeApps()"
        const warm = "index === 1) Services.ClipboardService.warmup()"
        const hint = "Services.WindowHintService.hintHeld"
        const advance = "root.startupTaskIndex = index + 1"
        root.check("the startup queue runs the three warmups one index apart",
                   body.length > 0
                   && body.indexOf(prime) >= 0
                   && body.indexOf(prime) < body.indexOf(warm)
                   && body.indexOf(warm) < body.indexOf(hint)
                   && body.indexOf(hint) < body.indexOf(advance)
                   && body.indexOf(advance) < body.indexOf("return true")
                   // An index past the list reports "nothing left", and it does so
                   // before the success return the timer reads.
                   && body.indexOf("else return false") >= 0
                   && body.indexOf("return true") > body.indexOf("else return false"),
                   "body: " + body.slice(0, 240))

        // The timer is what keeps the tasks apart: one tick each, and stopped on
        // entry so a boot that reports twice cannot stack a second queue. A
        // one-shot timer restarted per task would still be correct; a repeating
        // timer that is never stopped would call finishStartupWork repeatedly.
        const queueTimer = root.normalized(root.enclosingBlock("id: startupTaskTimer"))
        root.check("the startup queue runs one task per tick",
                   root.indexOf("id: startupTaskTimer") >= 0
                   && root.indexOf("id: startupTaskTimer") < root.chromeStart
                   && queueTimer.indexOf("{ id: startupTaskTimer") === 0
                   && queueTimer.indexOf("interval: 16") >= 0
                   && queueTimer.indexOf("running: false") >= 0
                   && queueTimer.indexOf("root.runStartupTask(root.startupTaskIndex)") >= 0
                   && queueTimer.indexOf("startupTaskTimer.stop()") >= 0
                   && queueTimer.indexOf("startupTaskTimer.restart()") >= 0
                   && queueTimer.indexOf("root.finishStartupWork()") >= 0,
                   "timer: " + queueTimer.slice(0, 240))

        // The latch: both reporters can arrive, in either order, and the queue may
        // only run once for a shell lifetime.
        const beginBody = root.normalized(root.bodyOf("function beginStartupWork()"))
        root.check("the startup queue starts once",
                   beginBody.indexOf("if (root.startupWorkStarted)") >= 0
                   && beginBody.indexOf("root.startupWorkStarted = true") >= 0
                   && beginBody.indexOf("startupTaskTimer.restart()") >= 0
                   && root.indexOf("property bool startupWorkStarted: false") >= 0,
                   "begin: " + beginBody.slice(0, 200))

        // Quiet-ready is the ladder's last stage, but it is *not* where the pulse comes
        // back: the wave is still animating at that point, so handing the timeline
        // over on quiet-ready would let a startup trigger draw over the wave the
        // lock just committed to. Both hand-backs belong to the end of the queue.
        const waveBody = root.normalized(root.bodyOf("function markStartupWaveStarted()"))
        root.check("quiet-ready does not hand back the pulse or the palette",
                   waveBody.length > 0
                   && waveBody.indexOf("startupMuted") < 0
                   && waveBody.indexOf("Services.ColorService") < 0
                   && waveBody.indexOf("root.startupQuietReady = true") >= 0,
                   "wave: " + waveBody.slice(0, 200))

        // The marker-spent reload, and the reason the queue cannot be wired to the
        // wave alone. That session has no startup lock, so no lock surface and no
        // startupWaveStarted signal ever fires; a queue waiting only on quiet-ready
        // would leave a reloaded shell with no launcher, no clipboard index and no
        // hint listener for the rest of its life.
        root.check("a reload with no startup wave still reaches the queue",
                   root.normalized(root.source).indexOf(
                       "readonly property bool startupWorkDue: root.startupChromeReady "
                           + "&& (root.startupQuietReady || !lockModule.startupLockExpected)")
                       >= 0,
                   "condition: " + root.normalized(root.source).slice(
                       Math.max(0, root.indexOf("startupWorkDue") - 80),
                       root.indexOf("startupWorkDue") + 200))

        // ...and the chrome readiness *guards* that pair rather than being one of
        // two alternatives: these warmups are deferred past the staged bar, so a
        // condition that opened on the lock's expectation alone would warm up
        // before the bar exists. Read as a single declaration, so a comment below
        // it cannot vouch for the expression above.
        const dueAt = root.indexOf("readonly property bool startupWorkDue:")
        const dueText = root.normalized(
            root.source.slice(dueAt, statementEnd(root.source, dueAt)))
        const chromeAt = dueText.indexOf("root.startupChromeReady")
        root.check("the queue waits for the staged chrome",
                   chromeAt >= 0
                   && dueText.indexOf("&&") > chromeAt
                   && dueText.indexOf("root.startupQuietReady") > chromeAt
                   && dueText.indexOf("!lockModule.startupLockExpected") > chromeAt,
                   "condition: " + dueText.slice(0, 200))

        // Both reporters reach the queue through the one condition, not through two
        // hand-written calls that could disagree about the latch.
        const dueHandler = root.normalized(root.enclosingBlock("onStartupWorkDueChanged:"))
        root.check("both startup reporters reach the queue through one condition",
                   dueHandler.indexOf("onStartupWorkDueChanged:") >= 0
                   && dueHandler.indexOf("if (startupWorkDue)") >= 0
                   && dueHandler.indexOf("root.beginStartupWork()") >= 0,
                   "handler: " + dueHandler.slice(0, 200))

        // The palette gate and the pulse unmute belong to the end of the queue, not
        // to the wave: nothing may pulse during staging, and nothing may keep
        // pulsing suppressed afterwards. The unmute goes first so a user action in
        // the same turn is never swallowed by the palette job.
        const finishBody = root.normalized(root.bodyOf("function finishStartupWork()"))
        const unmuteAt = finishBody.indexOf("Services.RipplePulseService.startupMuted = false")
        const paletteAt = finishBody.indexOf("Services.ColorService.startupQuietReady()")
        root.check("the queue unmutes the pulse and opens the palette gate last",
                   unmuteAt >= 0 && paletteAt > unmuteAt
                   && root.countOccurrences("Services.RipplePulseService.startupMuted = false") === 1
                   && root.countOccurrences("Services.ColorService.startupQuietReady()") === 1,
                   "finish: " + finishBody.slice(0, 200))

        // The pulse is muted from the root's own completion, so it is armed before
        // any chrome widget can move off its default, and the mute is never written
        // anywhere else — in particular not inside the service's own trigger path.
        const completedBody = root.normalized(
            root.source.slice(root.indexOf("Component.onCompleted: {"),
                              root.statementEnd(root.source,
                                                root.indexOf("Component.onCompleted: {"))))
        root.check("the pulse is muted from the root completion",
                   completedBody.indexOf("Services.RipplePulseService.startupMuted = true") >= 0,
                   "completion: " + completedBody.slice(0, 200))
        root.check("the pulse is only muted at startup",
                   root.countOccurrences("startupMuted") === 2
                   && root.positionInChrome("startupMuted") < 0,
                   "occurrences: " + root.countOccurrences("startupMuted"))
    }
}
