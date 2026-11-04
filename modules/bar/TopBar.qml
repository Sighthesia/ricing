import QtQuick
import Quickshell
import Quickshell.Wayland
import "../lazerbar"
import "./HintTitle.js" as HintTitle
import "../lazerbar/ScreenCornerMask.js" as CornerMask
import "../lazerbar/OverlayCoordinatorLogic.js" as CoordLogic
import "../lazerbar/WallpaperBootLogic.js" as BootLogic
import "./FullscreenBarLogic.js" as RevealLogic
import "./BarArrivalLogic.js" as ArrivalLogic
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections

// Mount the layout-driven bar plus the launcher wave owner per screen.
// BarPopupHost is mounted per screen and bound to BarContent hover intents.
Variants {
    id: root
    model: Quickshell.screens

    // Startup staging passes into each screen's BarContent; readiness flips
    // only after every current screen reports its widget batches complete.
    // Keys follow the WallpaperBootLogic "<name>@<x>,<y>,<w>x<h>" convention,
    // so a geometry change invalidates the old record and reporting stays
    // idempotent: duplicate reports collapse and never rebuild a bar.
    property bool startupStaging: false
    // Launcher page prewarm is deliberately held until the shell reaches its
    // quiet-ready phase; otherwise its first delegate/icon/font construction
    // competes with the startup reveal and bar staging.
    property bool startupPrewarmAllowed: false
    // Whether each bar's arrival may play. Held false while the desktop is owned
    // by a lock: a session-start lock has not left yet, or a request is standing
    // the desktop down so it can be photographed. Either way the slide would play
    // unseen, and the desktop would then appear with the bar already at rest
    // instead of arriving with it. The owning gates are the lock's own state, so a
    // session with no lock is unaffected.
    property bool arrivalAllowed: true
    property var finishedStartupScreens: []
    readonly property bool startupReady: BootLogic.isReady(
        root.finishedStartupScreens, root.currentStartupKeys())

    // Screen keys as they exist right now, so a resolution change drops the
    // completion recorded for the old geometry out of the readiness check.
    function currentStartupKeys() {
        return BootLogic.currentKeys(Quickshell.screens)
    }

    // Drop completions for screens that are gone, so unplugging a screen does
    // not leave its key behind to satisfy a later screen of the same name.
    function refreshStartupReady() {
        var current = root.currentStartupKeys()
        var retained = []
        for (var index = 0; index < root.finishedStartupScreens.length; index++) {
            if (current.indexOf(root.finishedStartupScreens[index]) >= 0)
                retained.push(root.finishedStartupScreens[index])
        }
        if (retained.length === root.finishedStartupScreens.length)
            return
        root.finishedStartupScreens = retained
    }

    // Record one screen's bar completion. Duplicate keys are ignored, so a
    // screen that reports twice cannot stand in for another screen.
    function reportBarReady(screenKey) {
        root.finishedStartupScreens = BootLogic.markFinished(root.finishedStartupScreens, screenKey)
        root.refreshStartupReady()
    }

    Scope {
        id: screenScope

        required property var modelData

        // Keep the theme's bar metrics tracking settings; the singleton itself
        // stays service-free so component suites run without Quickshell.
        Binding {
            target: LazerTheme
            property: "barHeightSetting"
            value: Services.SettingsService.bar.height
        }

        readonly property bool floating: Services.SettingsService.bar.floating
        readonly property int floatingMargin: floating
                ? Math.max(0, Math.min(24, Number(Services.SettingsService.bar.floatingMargin) || 0)) : 0
        readonly property int effectiveHeight:
            Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))
        // Where this bar's free edge currently sits, in screen coordinates, for
        // the desktop layer that paints the seam fillets. It is published rather
        // than derived because the painted bar travels on its own arrival and
        // auto-hide curve: settings do not describe it, and only this scope holds
        // the slide that does. See Services.BarSeamState.
        //
        // The surface is anchored on the bar's own edge with `floatingMargin`, so
        // the edge is that margin plus the strip; the slide offset then carries it
        // off the output on a collapse.
        readonly property real seamEdgeY: {
            const model = screenScope.modelData
            if (!model || !screenScope) return -1e6
            const strip = screenScope.effectiveHeight
            const margin = screenScope.floatingMargin
            const slide = barSlide ? Number(barSlide.y) : 0
            return screenScope.atTop
                ? margin + strip + slide
                : Number(model.height) - margin - strip + slide
        }
        onSeamEdgeYChanged: Services.BarSeamState.publish(screenScope.screenName, screenScope.seamEdgeY)
        onScreenNameChanged: Services.BarSeamState.publish(screenScope.screenName, screenScope.seamEdgeY)
        readonly property bool atTop: String(Services.SettingsService.bar.position || "top") !== "bottom"
        // Output identity, for effects that must only answer on their own
        // screen (the bar's glow pulse, for one).
        readonly property string screenName: screenScope.modelData ? String(screenScope.modelData.name || "") : ""
        // Where this output sits in the virtual desktop, and where the bar
        // window sits on it. The glow ring is shared in screen coordinates, and
        // `mapToGlobal` is per-window, so both have to be stated here rather
        // than measured inside a widget.
        readonly property real screenX: screenScope.modelData ? Number(screenScope.modelData.x || 0) : 0
        readonly property real screenY: screenScope.modelData ? Number(screenScope.modelData.y || 0) : 0
        readonly property real barWindowX: screenX + screenScope.floatingMargin
        readonly property real barWindowY: screenY + (screenScope.atTop ? screenScope.floatingMargin : 0)
        readonly property bool autoHideEnabled: Services.SettingsService.bar.autoHideFullscreen === true
        // Per-output: a fullscreen window on a background workspace of another
        // monitor must not collapse this screen's bar.
        //
        // Read the map, don't call the lookup: a binding needs a property it can
        // subscribe to, and this is the one the service reassigns.
        readonly property bool reportedFullscreen: {
            const verdicts = Services.NiriService.fullscreenOutputs
            const name = screenScope.modelData ? String(screenScope.modelData.name || "") : ""
            return screenScope.autoHideEnabled && !!verdicts && verdicts[name] === true
        }
        // The service's verdict, masked while this bar's own released strip is
        // what makes the tile measure fullscreen. The verdict is geometry alone,
        // and a maximized tile grows into the strip the frame that strip is
        // released — unmasked, the bar would read its own release as a
        // fullscreen window and stay hidden, and staying hidden is what keeps
        // the strip released: the bar returns only if this says false, and the
        // strip returns only once the bar has. Scoped to strips the release
        // actually moved tiles into (_stripMovedTiles), so a genuinely
        // fullscreen tile — which fills the output either way — still collapses
        // the bar.
        readonly property bool fullscreenActive: screenScope.reportedFullscreen
                && !(screenScope._stripMovedTiles && screenScope.stripReleased)
        // Whether this bar is holding its strip released right now: for as long
        // as a lock is photographing the desktop, and until this bar is back at
        // rest afterwards (_reclaimHold).
        readonly property bool stripReleased: Services.DesktopStandby.photographsDesktop
                || screenScope._reclaimHold
        // The masking above is dropped as soon as the service stops reporting
        // this output as filled — the reflow that returning the strip causes
        // lands in one geometry event, and until it arrives the verdict is still
        // reading this bar's own release. Not dropped while the release is still
        // this bar's to hold: during a request the bar has to stay off the
        // desktop whatever the tiles do.
        onReportedFullscreenChanged: {
            if (screenScope.reportedFullscreen)
                return
            if (Services.DesktopStandby.photographsDesktop || screenScope._reclaimHold)
                return
            screenScope._stripMovedTiles = false
        }

        // Fullscreen auto-hide state machine. `pinned` keeps the bar on screen
        // whenever something that anchors below it is open, so a popup or the
        // launcher can never render against a bar that is off-screen.
        property var _revealState: RevealLogic.initialState()
        readonly property bool revealed: _revealState.revealed
        // 0 while collapsed, 1 while shown. Drives the slide offset and the edge
        // hint only — the bar itself does not fade.
        //
        // A plain property, not a binding on `revealed`: the slide animation
        // writes it, and an animated target that is also bound is written
        // against its own binding. `onRevealedChanged` moves it instead, which
        // is also the only way to vary easing by direction. Starts shown, to
        // match initialState() and so the first frame is correct before any
        // event arrives.
        property real revealProgress: 1
        // Chrome arrival. Starts slid out, so a session has an arrival rather
        // than a pop-in, and it is deliberately NOT the state above: outside
        // fullscreen the auto-hide machine forces `revealed` true on every event
        // it sees, so an arrival stored in that state would be undone by the next
        // pointer move. The two are independent and combine into one slide,
        // which is also why neither may collapse the bar on its own.
        //
        // It runs in both directions. In, once this screen's widgets are staged
        // and nothing owns the screen; out, whenever a lock claims the desktop —
        // the lock photographs the desktop, so the bar has to be off it before
        // that capture (see Services.DesktopStandby).
        property real arrivalProgress: 0
        // Claimed for as long as the bar is meant to be at rest, so the full
        // input region belongs to it from the frame the arrival starts; a
        // stand-down hands the region back to the desktop.
        property bool arrivalClaimed: false
        // The only value the slide geometry reads.
        readonly property real slideProgress: ArrivalLogic.slideProgress(
            screenScope.revealProgress, screenScope.arrivalProgress)
        // Same motion contract as the auto-hide reveal above — an explicit
        // NumberAnimation rather than a Behavior, because a Behavior cannot vary
        // easing by direction and the arrival and the stand-down do not share a
        // curve.
        NumberAnimation {
            id: arrivalMotion
            target: screenScope
            property: "arrivalProgress"
            running: false
        }
        // This screen's widgets have staged. Staging is reported to the root
        // immediately (it is what closes the chrome gate the lock wave waits
        // on), but the arrival below is a separate decision.
        property bool startupStaged: false

        // Start the arrival when both this screen is staged and the desktop is
        // free again. Called from either condition changing, so an unlock that
        // lands before the widgets are staged still ends in an arrival, and the
        // call is idempotent afterwards.
        function maybeArrive() {
            if (!ArrivalLogic.shouldArrive(screenScope.startupStaged, root.arrivalAllowed))
                return
            screenScope.driveArrival(true)
        }
        // Qualified through the root, so the gate is unambiguous inside this
        // delegate: a Variants delegate resolves inherited handlers through a
        // scope chain that is not worth relying on.
        Connections {
            target: root
            function onArrivalAllowedChanged() {
                if (root.arrivalAllowed)
                    screenScope.maybeArrive()
                else
                    screenScope.driveArrival(false)
            }
        }

        // Drive the slide toward `atRest`, out of the bar's own viewport or back
        // into it. Per screen rather than on the root's aggregate readiness, so
        // each bar arrives when its own content exists instead of waiting for the
        // slowest monitor.
        //
        // The duration follows the distance still to travel, exactly like the
        // auto-hide reveal: an interrupted arrival resumes at a proportional
        // speed instead of jumping or lingering. The curves differ by direction
        // for the same reason they do above: OutCubic front-loads the arrival's
        // travel, while InOutQuad spends the whole duration visibly in motion, so
        // a departing bar reads as leaving rather than being erased.
        function driveArrival(atRest) {
            const target = atRest ? 1 : 0
            screenScope.arrivalClaimed = atRest === true
            // A bar popup is anchored to this bar and cannot outlive it. The
            // auto-hide collapse drops it outright for the same reason: the
            // pointer cannot be on a popup whose bar is off screen.
            if (!atRest)
                popupHost.dismissImmediately()
            arrivalMotion.stop()
            // Reduced motion arrives without travelling, the same way the
            // auto-hide reveal snaps when there is no distance left to cover.
            const distance = Math.abs(target - screenScope.arrivalProgress)
            if (MotionTokens.reducedMotion || distance < 0.001) {
                screenScope.arrivalProgress = target
                return
            }
            arrivalMotion.duration = Math.max(MotionTokens.fast,
                Math.round(MotionTokens.slow * distance))
            arrivalMotion.easing.type = atRest ? Easing.OutCubic : Easing.InOutQuad
            arrivalMotion.to = target
            arrivalMotion.restart()
        }

        // ---- The desktop's stand-down for a lock capture --------------------
        //
        // A lock request is routinely made from inside the launcher, and it
        // reaches the lock while the wave panel is still falling and the bar is
        // still painted. The lock's background is a photograph of the desktop, so
        // the capture waits for every surface that paints over the desktop to
        // report that it is clear (see Services.DesktopStandby). Each surface
        // registers while it exists and reports the frame it is actually gone;
        // a surface that never reports cannot strand the lock, which bounds its
        // own preparation and commits without a capture if this never settles.
        readonly property string barStandDownKey: screenName + ":bar"
        readonly property string waveStandDownKey: screenName + ":wave"
        readonly property string settingsStandDownKey: screenName + ":settings"
        // Per request, so a late report from the previous one cannot answer this
        // one.
        property bool _standDownReported: true
        // Whether this screen's tiles are still travelling into the strip this
        // bar just gave back (see the exclusive zone above and
        // reportBarStandDown below).
        property bool _reflowPending: false
        // Whether the strip this request gave back is one niri actually moves
        // tiles into, read from the verdict as it stands *before* the release
        // can have changed it (see the exclusive zone and applyStandDown). A
        // genuinely fullscreen covering tile is sized to the whole output
        // regardless, so releasing the strip moves no window: nothing to wait
        // for, and nothing to hold back when the request ends either. Latched
        // across the reclaim, since it is also what keeps the released strip
        // from being read back as a fullscreen window while the bar returns.
        property bool _stripMovedTiles: false
        // Whether this bar is still holding the strip open after the request
        // that released it has ended (see the exclusive zone above and
        // applyStandDown below). Cleared once the bar is back at rest, which is
        // the first moment returning the strip cannot expose the wallpaper: the
        // tiles then settle down behind a bar that already covers their edge.
        property bool _reclaimHold: false

        // Whether this output's active workspace has any window at all, read at
        // the moment a stand-down edge arrives. An empty desktop gives the strip
        // release nothing to re-tile: no window means no animated move, so the
        // reflow wait below can be skipped outright. Unknown workspace (the map
        // has not answered for this output yet) fails safe into waiting.
        readonly property bool _desktopHasWindows: {
            const active = Services.NiriService.activeWorkspaces
            const wsId = active ? active[screenName] : null
            if (wsId == null)
                return true
            const windows = Services.NiriService.windows
            for (let i = 0; i < windows.count; i++) {
                if (String(windows.get(i).workspaceId) === String(wsId))
                    return true
            }
            return false
        }

        // The wait for the desktop to actually stand in that strip. niri
        // re-tiles this screen's windows when the strip is released, and it
        // animates that with its own window-movement spring. The compositor
        // never announces the end of that animation: WindowLayoutsChanged
        // arrives once, at the animation START, already carrying the final
        // geometry (verified against this machine's event stream — only
        // interactive drags stream per frame), so no signal can end this wait
        // and it stays a budget. It is no longer a guessed one: this machine's
        // spring (damping 0.75, stiffness 323, slowdown 1.5) settles a
        // bar-height move to sub-pixel in about 300ms, so 400ms covers the
        // visible settle with margin. The old 1000ms was the spring's full
        // epsilon completion — three times longer than the eye can see, and it
        // sat between the wave panel landing and the lock appearing.
        readonly property int reflowBudgetMs: 400
        property Timer reflowTimer: Timer {
            interval: screenScope.reflowBudgetMs
            repeat: false
            onTriggered: {
                screenScope._reflowPending = false
                screenScope.reportBarStandDown()
            }
        }

        // Called from this scope's single destruction handler below: a Variants
        // delegate may declare `Component.onDestruction` once and no more.
        function releaseStandDown() {
            Services.DesktopStandby.unregister(screenScope.barStandDownKey)
            Services.DesktopStandby.unregister(screenScope.waveStandDownKey)
            Services.DesktopStandby.unregister(screenScope.settingsStandDownKey)
        }

        Component.onCompleted: {
            Services.DesktopStandby.register(screenScope.barStandDownKey)
            Services.DesktopStandby.register(screenScope.waveStandDownKey)
            Services.DesktopStandby.register(screenScope.settingsStandDownKey)
            // A scope created inside a capture window — a screen plugged in
            // mid-request — registered as owing a report and never saw the edge,
            // so it answers for itself here.
            screenScope.applyStandDown()
            // A bar already at rest never changes its edge, so a change handler
            // alone would leave the desktop layer with no position to paint the
            // seam at.
            Services.BarSeamState.publish(screenScope.screenName, screenScope.seamEdgeY)
        }

        // Answer the current request with every surface this screen owns. Called
        // on the request's own edge and from this scope's completion, so a scope
        // that appears mid-request owes exactly what one that saw the edge owes.
        function applyStandDown() {
            const standby = Services.DesktopStandby.standby
            const photographing = standby && Services.DesktopStandby.isPhotographingDesktop()
            // The release and the reflow it causes both start here, so the
            // budget is measured from this edge rather than from the slide
            // landing. Whether there is a reflow at all is decided from the
            // verdict as it stands before the release can have moved anything.
            screenScope.reflowTimer.stop()
            if (photographing) {
                // Latched rather than reconsidered per edge: this is what tells
                // the verdict above to keep ignoring a strip this bar released,
                // and it has to outlive the request, right through the reclaim
                // below. It is dropped by the verdict itself coming back down.
                screenScope._stripMovedTiles = !screenScope.reportedFullscreen
                if (screenScope._stripMovedTiles) {
                    screenScope._reclaimHold = true
                    // An empty desktop gives the release nothing to move, so
                    // the reflow wait is skipped outright instead of sitting a
                    // budget between the wave panel landing and the capture.
                    if (screenScope._desktopHasWindows) {
                        screenScope._reflowPending = true
                        screenScope.reflowTimer.restart()
                    } else {
                        screenScope._reflowPending = false
                    }
                }
            } else {
                // A request that photographs nothing has nothing to reclaim, and
                // one that ends has already latched what its reclaim needs.
                screenScope._reflowPending = false
            }
            // The bar has to be off the desktop for the capture whether or not
            // the release moved anything, so the reveal machine is told the
            // desktop is owned instead of being left to a fullscreen verdict
            // that a maximized tile only reaches because of this release.
            screenScope._sendReveal("standdown", photographing)
            screenScope._standDownReported = !standby
            screenScope.reportBarStandDown()
            screenScope.standDownWave()
            screenScope.standDownSettings()
        }

        Connections {
            target: Services.DesktopStandby
            function onStandbyChanged() { screenScope.applyStandDown() }
        }

        // The bar's own report, owed the frame it is actually off the desktop
        // rather than a duration after it was asked: watched on the slide, so a
        // reduced-motion snap and a slide that lands the ordinary way are the
        // same event. Both this and the reflow budget above feed the same
        // function, so whichever is the last to finish is what reports.
        onSlideProgressChanged: {
            screenScope.reportBarStandDown()
            // Back at rest, whichever slide brought it back: `slideProgress` is
            // the product of the reveal and the arrival, so 1 means both are in
            // place and the strip can be returned without exposing anything —
            // the tiles then settle down behind a bar that covers their edge.
            if (screenScope.slideProgress >= 1)
                screenScope._reclaimHold = false
        }

        function reportBarStandDown() {
            if (screenScope._standDownReported || !Services.DesktopStandby.standby)
                return
            if (screenScope.slideProgress > 0.001)
                return
            // Off the desktop, but the desktop itself is not standing still yet:
            // the tiles are still arriving in the strip this bar gave back.
            if (screenScope._reflowPending)
                return
            screenScope._standDownReported = true
            Services.DesktopStandby.report(screenScope.barStandDownKey)
        }

        // The wave panel is the surface a lock request most often arrives from:
        // the launcher's own locked-session row fires the request and closes
        // itself as it does, so the panel is still mid-fall when the lock would
        // capture. This waits for the panel's own `closed` instead, and closes it
        // itself when the request arrives by another route (a keybind).
        function standDownWave() {
            if (!Services.DesktopStandby.standby)
                return
            if (launcherSurface.host.phase === "closed") {
                Services.DesktopStandby.report(screenScope.waveStandDownKey)
                return
            }
            launcherSurface.host.close()
        }

        Connections {
            target: launcherSurface.host
            function onClosed() { screenScope.standDownWave() }
        }

        // A full-screen overlay in the same class: a lock request by keybind can
        // arrive with settings open, and the panel would be photographed exactly
        // like the wave panel would.
        function standDownSettings() {
            if (!Services.DesktopStandby.standby)
                return
            if (settingsOverlay.phase === "closed") {
                Services.DesktopStandby.report(screenScope.settingsStandDownKey)
                return
            }
            settingsOverlay.closeWithoutFocusRestore()
        }

        Connections {
            target: settingsOverlay
            function onClosed() { screenScope.standDownSettings() }
        }
        // Match the hover-popup reveal (see BarPopupHost.setRevealTarget): an
        // explicit NumberAnimation rather than a Behavior, because the popup
        // varies its easing per direction and a Behavior cannot. `onRevealedChanged`
        // sets duration/easing/to and restarts it.
        NumberAnimation {
            id: revealMotion
            target: screenScope
            property: "revealProgress"
            running: false
        }

        // Scale the duration by the distance still to travel, so an interrupted
        // slide resumes at a proportional speed instead of jumping or lingering.
        // This is the popup's rule verbatim; without it, revealing the bar and
        // then crossing the edge halfway back stalls for a full-duration wait.
        function revealDuration() {
            if (MotionTokens.reducedMotion)
                return MotionTokens.fast
            const distance = Math.abs((screenScope.revealed ? 1 : 0) - screenScope.revealProgress)
            if (distance < 0.001)
                return 0
            return Math.max(MotionTokens.fast, Math.round(MotionTokens.slow * distance))
        }
        // Anything that draws against the bar's own geometry pins it open: an
        // open bar popup, the launcher wave and the settings panel all anchor
        // below the bar, and none of them can render against a bar that is
        // off-screen. Opening the launcher from a fullscreen window therefore
        // also brings the bar back. The mod hint is named explicitly as well as
        // covered by `popupHost.open`, so the pin holds for the whole hold
        // rather than only for the frames the popup has finished opening.
        readonly property bool _pinned: popupHost.open
                || launcherSurface.host.interactive
                || settingsOverlay.interactive
                || screenScope.windowHintHeld
        readonly property bool windowHintHeld: Services.WindowHintService.hintHeld

        // Hold-key window hint, presented as a bar popup. The service owns the
        // snapshot; this scope only translates a hold into a hover intent and
        // back, so the hint reuses the popup's reveal, surface and input
        // region instead of owning a second floating surface.
        //
        // Identity keys stay constant across refreshes on purpose: the host
        // treats a same-identity intent as a live update and leaves the popup
        // in place, so switching workspaces while mod is held updates the rows
        // without a replacement crossfade.
        function buildWindowHintIntent() {
            const hint = Services.WindowHintService.activeHint
            if (!hint)
                return null
            return {
                widgetId: "window-hint",
                instanceKey: "hint:" + (screenScope.modelData ? String(screenScope.modelData.name || "") : ""),
                kind: "hover",
                actionKind: "window-hint",
                // THE SAME RAIL EVERY OTHER HOVER PANEL OPENS WITH.
                //
                // The hint used to be body-only, on the grounds that the bar already
                // reports the active workspace. That was right about the workspace and
                // wrong about the SHORTCUT: holding mod is how you ask what mod does,
                // and the panel answered with a window list and no word for the key
                // you were pressing. So the shared identity layer carries it, exactly
                // as it carries "Calendar" and "Volume" - icon, title, second line.
                //
                // The title is the live bind's action and the second line is its
                // sequence, because the answer to "what does this key do" is the
                // action; the sequence underneath confirms which key was understood.
                // Both come from the hint snapshot, which is republished while the
                // hold lasts, and the host treats a same-identity intent as a live
                // update - so a key press changes the rail in place instead of
                // replacing the panel.
                // What the rail says is one rule with three outcomes, so it lives
                // in `HintTitle.js` where it can be read and checked without a
                // shell: the overview is numbered ("Overview | Workspace 3"), a
                // workspace action is numbered too ("Next workspace | Workspace 4",
                // because a direction is the one thing a workspace key can get
                // wrong), and everything else is just its own name.
                title: HintTitle.title(
                    hint.bindLabel,
                    hint.bindIsNavigational === true,
                    hint.workspaceIndex,
                    function(key, args) { return Services.Tr.q(key, args) },
                    {
                        overview: "hint.overview",
                        overviewIndexed: "hint.overviewIndexed",
                        actionIndexed: "hint.actionIndexed",
                        workspaceLabel: "hint.workspaceLabel"
                    }),
                // The second line is the KEYS in BOTH states: the bound
                // combination once one has been pressed, and the mod key's own
                // name while the panel is just the overview. Showing the keys
                // only for bound actions left the overview with a blank line
                // where the answer to "what am I holding" belongs.
                summary: String(hint.bindSequence || ""),
                // The rail's lines are rewritten IN PLACE while the panel stays
                // put - a held mod key plus a tapped bound key - so they run the
                // shell's text transition and wash the rail with the shared flash
                // recipe. Told as a sentence with two halves: the title swaps, and
                // the rail says so.
                animatedText: true,
                changeFlash: true,
                // What the announcement is keyed on: the number of shortcuts fired.
                // Text changes alone do not announce - the overview's title gains
                // its workspace number a frame after the panel opens, and that is
                // the panel settling, not the user pressing something.
                announceToken: Number(hint.bindToken || 0),
                // A keyboard glyph in both states, tinted like every other
                // monochrome module glyph: the panel is an answer about KEYS
                // whether it is naming a bound action or showing the overview.
                iconSource: Qt.resolvedUrl("../lazerbar/icons/keyboard.svg"),
                tintIcon: true,
                anchorX: barContent.hintAnchorX(),
                screenWidth: screenScope.modelData ? Number(screenScope.modelData.width) : 1920,
                screenHeight: screenScope.modelData ? Number(screenScope.modelData.height) : 1080,
                barPosition: String(Services.SettingsService.bar.position || "top"),
                effectiveBarHeight: screenScope.effectiveHeight,
                floatingMargin: screenScope.floatingMargin,
                payload: {
                    hint: hint,
                    // niri owns window activation; the route matches the
                    // workspace widget's own window chips.
                    onHintWindow: windowId => Quickshell.execDetached([
                        "niri", "msg", "action", "focus-window", "--id", String(windowId)
                    ])
                }
            }
        }

        function openWindowHint() {
            const intent = buildWindowHintIntent()
            if (!intent)
                return
            // Nothing hovers this popup, so the host's own hover owner has to
            // be latched or the close timer would retire it on the first tick.
            popupHost.widgetHovered = true
            popupHost.updateIntent(intent)
        }

        function refreshWindowHint() {
            if (!Services.WindowHintService.hintHeld)
                return
            const intent = buildWindowHintIntent()
            if (intent)
                popupHost.updateIntent(intent)
        }

        function closeWindowHint() {
            // A widget can still sit under the pointer: hand its popup back
            // rather than closing the surface, because the widget emits no new
            // hover event and would otherwise stay popup-less until the
            // pointer left and returned.
            if (barContent.reemitHoverIntent())
                return
            popupHost.widgetHovered = false
            popupHost.dismissAnimated()
        }

        // Feed one transition into the state machine. The returned state is
        // always stored; only the reveal edge effects (drop a popup, arm the
        // idle collapse) are edge-triggered, so an event that changes nothing
        // visible cannot skip a state field the next reduce needs.
        function _sendReveal(type, value, distance) {
            const wasRevealed = _revealState.revealed
            const next = RevealLogic.reduce(_revealState, {
                type: type,
                value: value,
                distance: distance
            })
            _revealState = next
            // `revealed` is a binding on `_revealState`, so it has not been
            // re-read yet at this point. The animation is kicked off from the
            // reveal edge below, against the state we actually computed.
            if (wasRevealed && !next.revealed) {
                // A bar popup is opened by hovering a widget, and the pointer
                // cannot be on one while the bar is off-screen.
                popupHost.dismissImmediately()
                _hideTimer.stop()
                if (type !== "leave")
                    _revealState = RevealLogic.rearmAfterCollapse(_revealState, _pointerDistance)
            } else if (next.revealed && !wasRevealed) {
                // Arm the safety net only when the pointer is not on the bar.
                // While it is, `leave` owns the collapse, and a timer racing the
                // cursor makes the bar strobe.
                if (!next.hovered)
                    _hideTimer.restart()
            }
        }

        // Fire the slide. Driven off the state rather than a Behavior, so the
        // duration and easing can follow the direction of travel.
        //
        // Enter uses OutCubic and exit InOutQuad, the popup's pair. The
        // direction matters: OutCubic front-loads travel, so a bar leaving that
        // way spends its last frames barely moving and the departure looks like
        // it stalls at the edge. InOutQuad spends the whole duration visibly in
        // motion, which reads as the bar leaving rather than being erased.
        onRevealedChanged: {
            revealMotion.stop()
            const target = revealed ? 1 : 0
            if (Math.abs(target - revealProgress) < 0.001) {
                revealProgress = target
                return
            }
            revealMotion.duration = revealDuration()
            revealMotion.easing.type = revealed ? Easing.OutCubic : Easing.InOutQuad
            revealMotion.to = target
            revealMotion.restart()
        }

        // Last known distance of the pointer from the bar's anchored edge, valid
        // only while the pointer is actually over the bar. Negative means "not
        // known", which rearmAfterCollapse treats as "arm".
        //
        // It must be forgotten on leave, not merely left behind: once the bar is
        // collapsed its input region is only the edge strip, so a pointer that
        // sits in the middle of the bar stops producing position events entirely.
        // A stale distance would then decide the next collapse, and the commonest
        // case — fullscreen toggled while the pointer is mid-screen — would
        // disarm the strip for a pointer that is nowhere near it.
        property real _pointerDistance: -1

        function _notePointerDistance(distance) {
            if (!isFinite(Number(distance)))
                return
            _pointerDistance = Number(distance)
            _sendReveal("move", undefined, _pointerDistance)
        }

        function _forgetPointer() {
            _pointerDistance = -1
        }

        // Safety net only. Leaving the bar collapses it at once via a `leave`
        // event; this covers the case where no leave ever arrives (the pointer
        // arrived before the surface was listening, or the hover was never
        // established). It is deliberately not armed while the pointer is on the
        // bar — a timer firing under a resting cursor made the bar strobe.
        Timer {
            id: _hideTimer
            interval: Math.max(RevealLogic.minTimerInterval, RevealLogic.idleHideDelay)
            onTriggered: {
                if (!screenScope.revealed || !screenScope.fullscreenActive
                        || screenScope._pinned || screenScope._revealState.hovered)
                    return
                screenScope._sendReveal("idle")
            }
        }

        // Mirror the reveal chain for out-of-process inspection. A collapse that
        // silently fails looks identical to one that never triggered, so the
        // debugFullscreenBar IPC target reads this instead of guessing.
        readonly property var _debugEntry: ({
            screenName: screenName,
            fullscreenActive: fullscreenActive,
            autoHideEnabled: autoHideEnabled,
            revealed: revealed,
            revealProgress: revealProgress,
            // The arrival side of the same question: a bar that is off screen
            // because it has not arrived, or because it is standing down for a
            // lock capture, looks identical to one the auto-hide machine
            // collapsed, and only these two fields tell them apart from outside
            // the process.
            arrivalClaimed: arrivalClaimed,
            slideProgress: slideProgress,
            arrivalProgress: arrivalProgress,
            stripReleased: stripReleased,
            stripMovedTiles: _stripMovedTiles,
            reflowPending: _reflowPending,
            reclaimHold: _reclaimHold,
            pinned: _pinned,
            state: _revealState
        })
        on_DebugEntryChanged: Services.BarDebugState.sync(screenName, _debugEntry)
        Component.onDestruction: {
            Services.BarDebugState.remove(screenName)
            Services.BarSeamState.remove(screenName)
            screenScope.releaseStandDown()
        }

        onFullscreenActiveChanged: _sendReveal("fullscreen", fullscreenActive)
        onAutoHideEnabledChanged: _sendReveal("enabled", autoHideEnabled)
        // Losing the pin (a popup or overlay just closed) must not strand a bar
        // that was only visible because of it: the pointer left the surface
        // while the pin held it open, so nothing else will collapse it.
        on_PinnedChanged: {
            _sendReveal("pinned", _pinned)
            if (!_pinned && screenScope.revealed && screenScope.fullscreenActive
                    && !screenScope._revealState.hovered)
                _hideTimer.restart()
        }

        // Desktop-blocking mask only when the debug override demands it.
        readonly property bool settingsMaskActive:
            Services.SettingsService.settingsMaskOverride !== "off"
            && settingsOverlay.blocksDesktop

        // The shared seam for one screen's *targeted* overlay requests, so a
        // wave route cannot end up reachable by two different spellings. Every
        // future bar affordance that names an overlay target goes through it.
        //
        // It is NOT the only way an overlay opens, and nothing here may be built
        // on that assumption. These each ask one owner they already know:
        //
        //   - the launcher entry and the launcher's keybind/IPC drive
        //     Services.LauncherService, which reaches this surface as session
        //     visibility and is mirrored by LauncherSurface.syncVisibility
        //   - the gear entry and a widget's settings action ask
        //     SettingsOverlayBridge.requestOpen()
        //   - the island-settings mirror and a widget settings open, further down
        //     this file, ask overlayCoordinator.request("settings", ...) directly,
        //     because they must dismiss the popup host on the way
        //
        // Those are owner-specific paths, not a second dispatch table. What
        // belongs here is a request that has to *choose* between owners.
        //
        // The wave's two routes are exactly that case: they go through the
        // launcher surface rather than through the coordinator, because that
        // surface owns the session mirror, the opener record and the focus
        // hand-off for both of them; the coordinator would open the host with
        // none of that. Which of its two methods answers is read from the
        // coordinator's own registry, so the launcher and the control center
        // cannot be reached by two spellings of one owner.
        //
        // The control center no longer has a bar entry at all - it is reached
        // from the launcher's rail, which switches the route on a surface that
        // is already open and so never comes through here. The dispatch below is
        // kept because the registry still names both routes for the launcher
        // surface, and a wave target refused here must fail loudly rather than
        // open a route without that surface's session and opener bookkeeping.
        //
        // Everything else is a separate owner and goes straight to the
        // coordinator, which keeps its existing mutual exclusion and opener
        // restoration untouched.
        function requestOverlay(target, opener) {
            var plan = CoordLogic.dispatchFor(target, launcherSurface)
            if (plan.route === "wave") {
                launcherSurface[plan.method](opener)
                return
            }
            if (plan.route === "coordinator") {
                overlayCoordinator.request(target, opener)
                return
            }
            // A wave target the owner does not implement: the route registry and
            // the surface have drifted. Report it rather than dispatching it,
            // because the coordinator would open the host with no session mirror,
            // no requestedRoute and no opener - a route on screen that every
            // later decision still believes is closed.
            //
            // This file is named in the message on purpose: QML's console.warn
            // carries no source location, so without it the diagnostic never
            // reaches scripts/check-shell.sh, which classifies on a repo path.
            console.warn("modules/bar/TopBar.qml: refused wave target '" + target
                + "', the wave owner has no '" + plan.method
                + "' entry method and the coordinator cannot open it either")
        }

        // Serialize launcher transitions; settings/music owners live elsewhere.
        OverlayCoordinator {
            id: overlayCoordinator
            onOpenRequested: (owner, target) => {
                if (owner === "wave") launcherSurface.host.openRoute(target, null)
                else if (owner === "settings") settingsOverlay.openFrom(null, true)
            }
            onCloseRequested: owner => {
                if (owner === "wave") launcherSurface.host.close()
                else if (owner === "settings") settingsOverlay.closeWithoutFocusRestore()
            }
        }

        // Bar-side open intents (gear button) join the same serialized path.
        Connections {
            target: SettingsOverlayBridge
            function onOpenRequested() {
                overlayCoordinator.request("settings", null, true)
            }
        }

        // Drive the hold-key window hint through the shared popup host. One
        // connection per screen scope, so every screen shows the same snapshot
        // anchored over its own bar; the service is a singleton, so this is the
        // only place the trigger is consumed.
        //
        // The snapshot refresh lands separately from the hold: a workspace
        // switch while mod is down is a data change, not a reopen, and must
        // keep the popup in place.
        Connections {
            target: Services.WindowHintService
            function onHintHeldChanged() {
                if (Services.WindowHintService.hintHeld)
                    screenScope.openWindowHint()
                else
                    screenScope.closeWindowHint()
            }
            function onActiveHintChanged() {
                screenScope.refreshWindowHint()
            }
        }

        // Report this screen's staged widgets without touching the bar:
        // the registry dedupes repeats, so a second report changes nothing.
        // The key follows the boot convention, so a geometry change re-keys
        // this screen; if its batches already finished, the new key reports
        // at once instead of stranding readiness on the old geometry.
        readonly property string startupScreenKey: BootLogic.screenKey(
            screenScope.modelData.name, screenScope.modelData.x,
            screenScope.modelData.y, screenScope.modelData.width,
            screenScope.modelData.height)
        onStartupScreenKeyChanged: {
            if (barContent && barContent.startupReady)
                root.reportBarReady(screenScope.startupScreenKey)
        }
        Connections {
            target: barContent
            function onStartupReadyChanged() {
                if (!barContent.startupReady)
                    return
                root.reportBarReady(screenScope.startupScreenKey)
                screenScope.startupStaged = true
                screenScope.maybeArrive()
            }
        }

        // Prune finished keys the moment the screen set changes, so an
        // unplugged screen's key never lingers past the hotplug. This lives
        // on the Scope because Variants drops arbitrary root children.
        Connections {
            target: Quickshell
            function onScreensChanged() {
                root.refreshStartupReady()
            }
        }

        // The hint's anchor is the bar's own midpoint, so a bar width change is
        // the only thing that can invalidate it.
        Connections {
            target: barContent
            function onAnchorInvalidated() { screenScope.refreshWindowHint() }
        }

        // Mirror the shared island settings route into this screen's owner.
        // SettingsService changes IslandService state before this window can
        // animate, so both the IPC and bar-button paths stay consistent.
        Connections {
            target: Services.IslandService
            function syncSettingsOverlay() {
                var settingsOpen = Services.IslandService.expanded
                        && Services.IslandService.panelPage === "settings-center"
                if (settingsOpen) {
                    popupHost.dismissImmediately()
                    overlayCoordinator.request("settings", null, true, true)
                } else if (settingsOverlay.interactive
                           && overlayCoordinator.activeTarget === "settings") {
                    settingsOverlay.closeWithoutFocusRestore()
                }
            }
            function onExpandedChanged() { syncSettingsOverlay() }
            function onPanelPageChanged() { syncSettingsOverlay() }
        }

        // Open the shared settings surface for a widget context action.
        Connections {
            target: Services.BarLayoutService
            function onWidgetSettingsVisibleChanged() {
                if (!Services.BarLayoutService.widgetSettingsVisible)
                    return
                popupHost.requestAnimatedClose()
                settingsOverlay.prepareDebugOpen()
                settingsOverlay.panel.selectedCategory = Services.BarLayoutService.widgetSettingsSection === "right"
                        ? "notifications" : "bar"
                overlayCoordinator.request("settings", null, true, true)
            }
        }

        PanelWindow {
            id: barWindow

            screen: screenScope.modelData
            color: "transparent"
            // Name the surface so compositor diagnostics can identify it.
            WlrLayershell.namespace: "afloat-bar"
            // Keep the physical bar above popup surfaces and normal windows.
            WlrLayershell.layer: WlrLayer.Overlay
            // Strip height only. The bar's seam fillets are not painted here:
            // they hang past this rectangle and must sit under tiled windows, so
            // the desktop layer paints them (see Services.BarSeamState).
            implicitHeight: screenScope.effectiveHeight
            // Deliberately NOT released while the bar collapses. niri sizes a
            // fullscreen tile to the whole output, so the reserved strip is
            // invisible during fullscreen; dropping it would instead reflow every
            // tiled window twice per fullscreen toggle.
            //
            // It IS released for as long as a lock is capturing the desktop: that
            // capture is a photograph of a desktop with no bar on it, and a strip
            // the tiles stay excluded from would be photographed as a hole where
            // the bar used to be (see Services.DesktopStandby.photographsDesktop).
            // What the release sets in motion — niri re-tiling this screen's
            // windows into the strip — is what the stand-down report waits out
            // below, because the photograph is taken after that report.
            //
            // It stays released past the end of the request until this bar is
            // back at rest (_reclaimHold): giving the strip back the moment the
            // request ends pushes the tiles down while the bar is still arriving
            // above them, and the wallpaper shows in the gap between the two.
            exclusiveZone: (screenScope.floating
                            || screenScope.stripReleased) ? 0 : implicitHeight
            anchors { top: screenScope.atTop; bottom: !screenScope.atTop; left: true; right: true }
            margins { top: screenScope.floatingMargin; bottom: screenScope.floatingMargin; left: screenScope.floatingMargin; right: screenScope.floatingMargin }

            // While collapsed the surface claims only a thin strip at the bar's
            // anchored edge. Keeping the probe on this same surface avoids a
            // second overlay-layer surface, whose z-order against this one the
            // compositor decides and the client cannot pin.
            //
            // The source is a bare Item, exactly like BarPopupHost's
            // popupFullRegion: it exists only to give the mask a geometry.
            mask: Region { item: revealProbe }

            // Slide the painted bar out of view. Only the inner content moves, so
            // the layer-shell surface, its exclusive zone and its blur region
            // never resize per frame. The offset reads `slideProgress`, the
            // product of the auto-hide reveal and the startup expansion, so this
            // is the one place either mechanism can take the bar off screen.
            //
            // No opacity on this container: the bar translates as a solid object
            // and never fades. A bar that dissolves while sliding reads as two
            // things happening at once and looks half-broken on a fast throw,
            // and osu!lazer's panel moves are position-only for the same reason.
            // The edge hint below is the only thing that fades, since it is a
            // cue rather than a surface in motion.
            //
            // Geometry is set outright rather than with anchors.fill: an explicit
            // `y` would silently fight the top anchor, and a per-frame re-anchor
            // is exactly the kind of resize the note above rules out.
            Item {
                id: barSlide
                x: 0
                y: (1 - screenScope.slideProgress)
                        * (screenScope.atTop ? -barSlide.height : barSlide.height)
                width: parent.width
                height: parent.height

                // Paint the continuous sharp bar silhouette behind every widget.
                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Services.SettingsService.effectiveColorScheme === "light" ? LazerTheme.bgLight : LazerTheme.bgDark
                    opacity: Math.max(0.35, Math.min(1, Services.SettingsService.panelSurfaceOpacity))

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                    Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                }

                // The shell's single glow pulse, hosted on the bar: the same
                // heavy ring and its two soft bands the notification card
                // plays, swept across this strip instead of the whole display
                // and clipped to it. Painted under the widgets so the sweep
                // lights the bar's own surface and the glyphs stay legible.
                RippleGlow {
                    id: barGlow

                    anchors.fill: parent
                    pulse: Services.RipplePulseService
                    screenName: screenScope.screenName
                    screenWidth: Number(screenScope.modelData ? screenScope.modelData.width : 0)
                    screenHeight: Number(screenScope.modelData ? screenScope.modelData.height : 0)
                    // The glow fills the bar window, so the window's own place
                    // on the output is also this item's place on it.
                    hostScreenX: screenScope.barWindowX
                    hostScreenY: screenScope.barWindowY
                    glowEnabled: Services.SettingsService.appearance.ripplePulseEnabled !== false
                }

                BarContent {
                    id: barContent
                    anchors.fill: parent
                    screenName: screenScope.screenName
                    screenX: screenScope.barWindowX
                    screenY: screenScope.barWindowY
                    startupStaging: root.startupStaging

                    // While mod is held the hint owns the popup, so a widget's own hover traffic
                    // must not reach the host. Two reasons, both observable:
                    // a leave from the widget the pointer started on would run
                    // the host's close timer and retire the hint while mod is
                    // still down, and a second widget's hover or anchor update
                    // would take the popup over mid-hold, turning every refresh
                    // into an alternating replacement crossfade. The widget's
                    // recorded intent is kept either way, so releasing mod hands
                    // the popup straight back to it (see closeWindowHint).
                    readonly property bool hintOwnsPopup: screenScope.windowHintHeld

                    // Forward hover intents to the per-screen popup host.
                    onPopupRequested: intent => {
                        if (!intent || screenScope.hintOwnsPopup) return
                        var enriched = Object.assign({}, intent)
                        enriched.screenWidth = screenScope.modelData ? Number(screenScope.modelData.width) : 1920
                        enriched.screenHeight = screenScope.modelData ? Number(screenScope.modelData.height) : 1080
                        enriched.barPosition = String(Services.SettingsService.bar.position || "top")
                        enriched.effectiveBarHeight = screenScope.effectiveHeight
                        enriched.floatingMargin = screenScope.floatingMargin
                        popupHost.widgetHovered = true
                        popupHost.updateIntent(enriched)
                    }
                    onPopupCloseRequested: {
                        if (screenScope.hintOwnsPopup) return
                        // A tray icon losing hover must not retire a context
                        // menu, which is dismissed explicitly and not by the
                        // pointer wandering off a widget.
                        if (popupHost.currentIntent
                                && String(popupHost.currentIntent.kind || "") === "context")
                            return
                        popupHost.widgetHovered = false
                        popupHost.requestClose()
                    }
                    onPopupAnchorUpdate: intent => {
                        if (!intent || !popupHost.open || screenScope.hintOwnsPopup) return
                        var enriched = Object.assign({}, intent)
                        enriched.screenWidth = screenScope.modelData ? Number(screenScope.modelData.width) : 1920
                        enriched.screenHeight = screenScope.modelData ? Number(screenScope.modelData.height) : 1080
                        enriched.barPosition = String(Services.SettingsService.bar.position || "top")
                        enriched.effectiveBarHeight = screenScope.effectiveHeight
                        enriched.floatingMargin = screenScope.floatingMargin
                        // Refresh all slot data in place without recreating the reveal.
                        if (popupHost.intent)
                            popupHost.updateIntent(enriched)
                        popupHost.cancelClose()
                    }
                    onContextPopupRequested: intent => {
                        if (!intent) return
                        var enriched = Object.assign({}, intent)
                        enriched.screenWidth = screenScope.modelData ? Number(screenScope.modelData.width) : 1920
                        enriched.screenHeight = screenScope.modelData ? Number(screenScope.modelData.height) : 1080
                        enriched.barPosition = String(Services.SettingsService.bar.position || "top")
                        enriched.effectiveBarHeight = screenScope.effectiveHeight
                        enriched.floatingMargin = screenScope.floatingMargin
                        popupHost.widgetHovered = true
                        popupHost.updateIntent(enriched)
                    }
                    onContextPopupCloseRequested: {
                        popupHost.widgetHovered = false
                        popupHost.requestClose()
                    }
                }
            }

            // The surface's input region. Revealed, it is the whole bar; while
            // collapsed it is only this strip at the bar's anchored edge, which
            // is what makes the bar recallable while a fullscreen window holds
            // the screen. Switching it outright (never per frame) costs nothing:
            // the pointer has to already sit on the strip to trigger a reveal.
            Item {
                id: revealProbe
                width: barSlide.width
                height: ArrivalLogic.claimsFullRegion(screenScope.revealed,
                                                       screenScope.arrivalClaimed)
                        ? barSlide.height : RevealLogic.revealStripHeight
                y: screenScope.atTop ? 0 : barSlide.height - height
            }

            // Painted hint that a collapsed bar is still here. A sharp
            // rectangular bar, like the bar itself — no rounding on a major
            // surface.
            Rectangle {
                width: barSlide.width
                height: RevealLogic.revealStripHeight
                y: screenScope.atTop ? 0 : barSlide.height - height
                radius: 0
                color: Services.SettingsService.effectiveColorScheme === "light"
                        ? LazerTheme.bgLight : LazerTheme.bgDark
                // Faded out with the arrival rather than switched off with it: a
                // stand-down has to take this hint with it — the lock photographs
                // the desktop, and a bar that is not in the picture must not leave
                // a strip of itself in it. Multiplying is what makes the collapse
                // of an already auto-hidden bar read as one motion.
                opacity: (1 - screenScope.revealProgress)
                        * screenScope.arrivalProgress
                        * Math.max(0.35, Math.min(1, Services.SettingsService.panelSurfaceOpacity)) * 0.7

                Behavior on opacity { NumberAnimation { duration: MotionTokens.medium } }
            }

            // Hover probe. This surface stays mapped and the pointer stays over
            // it while collapsed, so a reveal must consume the arm; only a
            // pointer that travels back out past the strip re-arms it.
            HoverHandler {
                id: surfaceHover
                onHoveredChanged: {
                    if (hovered) {
                        screenScope._sendReveal("enter")
                        // Deliberately no timer restart here. The pointer is on
                        // the bar, so `leave` is what must collapse it; letting a
                        // timer fire underneath a resting cursor made the bar
                        // strobe between every reveal and its own hide.
                    } else {
                        // The pointer is gone from the surface, so any distance
                        // it had is no longer evidence about the edge strip.
                        screenScope._forgetPointer()
                        screenScope._sendReveal("leave")
                        _hideTimer.stop()
                    }
                }
                onPointChanged: {
                    screenScope._notePointerDistance(
                        RevealLogic.distanceFromEdge(
                            point.position.y, barSlide.height, screenScope.atTop))
                    // Moving over the bar must not arm the collapse either.
                    if (!screenScope._revealState.hovered)
                        _hideTimer.restart()
                }
            }
            // The screen bezel corners this bar physically covers. The bezel's
            // own surface is a separate overlay-layer surface, and a client
            // cannot order two of them against each other, so the corners the
            // bar overlaps are painted here instead: above this window's own
            // fill they are always the topmost thing, whatever the compositor
            // does with the other surface. Painted after the fill so the wedge
            // stays opaque black rather than being tinted by it.
            //
            // On the surface, not on the sliding strip: the strip leaves the
            // screen when the bar auto-hides, and the bezel surface is told to
            // skip these corners for as long as this bar owns them. Sliding them
            // away with the strip took the screen's rounding with it — a
            // fullscreen window then ran into square display corners until the
            // bar came back.
            ScreenCornerMask {
                anchors.fill: parent
                radius: Math.max(0, Number(Services.SettingsService.appearance.screenCornerRadius) || 0)
                corners: CornerMask.barCornerMask(
                    String(Services.SettingsService.bar.position || "top"),
                    Services.SettingsService.bar.floating === true)
                // Clamp against the screen, not against this one-strip-tall
                // window, so the radius matches the corners the bezel surface
                // paints on the opposite edge.
                screenWidth: screenScope.modelData.width
                screenHeight: screenScope.modelData.height
            }
        }

        // Per-screen hover popup host. One instance per screen scope; no per-widget hosts.
        BarPopupHost {
            id: popupHost
            screen: screenScope.modelData
            screenWidth: screenScope.modelData ? Number(screenScope.modelData.width) : 1920
            screenHeight: screenScope.modelData ? Number(screenScope.modelData.height) : 1080
            effectiveBarHeight: screenScope.effectiveHeight
            floatingMargin: screenScope.floatingMargin
        }

        Connections {
            target: SettingsOverlayBridge
            function onOpenRequested() { popupHost.requestAnimatedClose() }
        }

        // Keep the launcher wave below the bar while only its internal viewport moves.
            PanelWindow {
                id: launcherWindow
                screen: screenScope.modelData; color: "transparent"
                WlrLayershell.namespace: "afloat-launcher"
            implicitWidth: screenScope.modelData.width; implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            // Offset by the same clamped height the bar actually renders at.
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0 }
            mask: Region { item: launcherSurface.host.visible ? launcherSurface.host : null }
            // Take keyboard only while the launcher is up so typing reaches its
            // search field and global keys stay free when closed.
            WlrLayershell.keyboardFocus: launcherSurface.host.interactive
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            LauncherSurface {
                id: launcherSurface; anchors.fill: parent
                coordinator: overlayCoordinator
                session: Services.LauncherService
                startupPrewarmAllowed: root.startupPrewarmAllowed
                // Owner edge for the control-center view: the same singletons
                // the bar's own popups read, so the overview, its same-surface
                // sub-pages and the bar can never disagree about one service
                // instance. Media is MediaService rather than
                // MediaControlService because this route needs the transport
                // actions the latter does not own.
                networkService: Services.NetworkService
                bluetoothService: Services.BluetoothService
                volumeService: Services.VolumeService
                mediaService: Services.MediaService
                batteryService: Services.BatteryService
                notificationService: Services.NotificationService
                weatherService: Services.WeatherService
            }
        }

        // Keep Settings in a dedicated left-side owner with no full-screen mask.
            PanelWindow {
                id: settingsWindow
                screen: screenScope.modelData; color: "transparent"
                WlrLayershell.namespace: "afloat-settings"
                // Settings must remain visible above the fixed popup owners.
                WlrLayershell.layer: WlrLayer.Overlay
            implicitWidth: Math.min(LazerTheme.settingsPanelWidth, screenScope.modelData.width)
            implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0 }
            mask: Region { item: screenScope.settingsMaskActive ? settingsOverlay : null }
            // Take keyboard only while settings is open so typing reaches its
            // text fields and global keys stay free when closed.
            WlrLayershell.keyboardFocus: settingsOverlay.interactive
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            LazerSettingsOverlay {
                id: settingsOverlay; anchors.fill: parent
                // Configured on the overlay, not through `panel.*`: the panel is
                // built on first open, so during construction the handle is null
                // and writing to it fails the config to load. The overlay holds
                // these inputs and hands them to the panel when it arrives.
                appearanceSettings: Services.SettingsService.appearance
                barSettings: Services.SettingsService.bar
                notificationSettings: Services.SettingsService.notifications
                saveCallback: Services.SettingsService.save
                appearanceDefaults: Services.SettingsService.appearanceDefaults
                barDefaults: Services.SettingsService.barDefaults
                notificationDefaults: Services.SettingsService.notificationDefaults
                settingsReset: Services.SettingsService.resetCategorySetting
                wallpaperService: Services.WallpaperService
                locationService: Services.LocationService
                effectiveSunrise: Services.SettingsService.effectiveSunrise
                effectiveSunset: Services.SettingsService.effectiveSunset
                coordsValid: Services.SettingsService.locationCoordsValid
                locationError: Services.LocationService.lastError
                locationDisplayName: Services.LocationService.displayName
                debugHoverEnabled: Services.SettingsService.hoverDebugEnabled
                debugHoverToken: Services.SettingsService.hoverDebugToken
                debugMaskOverride: Services.SettingsService.settingsMaskOverride
                debugMaskActive: screenScope.settingsMaskActive
                debugScreenName: screenScope.modelData && screenScope.modelData.name
                        ? String(screenScope.modelData.name) : "unknown"
                onClosed: overlayCoordinator.ownerClosed("settings")
            }
        }
    }
}
