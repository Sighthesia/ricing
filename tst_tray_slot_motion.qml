import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "./modules/bar/widgets" as Widgets
import "./modules/lazerbar" as Lazer

// Tray enter/exit choreography against synthetic StatusNotifier items.
//
// Root-level on purpose: Tray.qml imports Quickshell, which plain QtTest
// cannot load (the plugin is linked into `qs`, not installed as a QML module).
// Headless-safe: the widget declares no PanelWindow, so it loads under the
// offscreen platform without ever mapping a surface.
//
// The session's real tray is carried through the run instead of being ignored:
// the fakes are added on top of it, so a live desktop cannot make the counts
// drift, and the strip is asserted to behave next to real icons.
Item {
    id: probe

    width: 400
    height: 120

    property int failures: 0
    property int elapsed: 0
    property var queue: []
    property bool done: false
    // A monotonic schedule: each step is relative to the one before it.
    property int clock: 0
    property int polls: 0
    property var sessionItems: []
    // Sampler bookkeeping for the arrival window.
    property bool sawClosedBox: false
    property int inkBeforeBox: 0
    property int ghostedSlots: 0
    property bool faded: false
    property bool landed: false

    readonly property var tokens: Lazer.MotionTokens

    // The width a settled n-icon strip must report: every slot carries its own
    // trailing gap, minus the one the last slot does not need.
    function settledWidth(count) {
        return count * (Lazer.LazerTheme.barWidgetHeight + 2) - 2
    }

    function check(name, condition, detail) {
        if (condition) {
            console.log("PASS:", name)
        } else {
            probe.failures++
            console.log("FAIL:", name, detail === undefined ? "" : detail)
        }
    }

    // Fake tray items. `id` cannot be declared in QML (reserved for object
    // identity), so these exercise the title fallback of slotKey(); the SNI id
    // path is covered by tests/qml/tst_bar_tray_motion.qml.
    QtObject {
        id: itemA
        property string title: "Alpha"
        property string icon: ""
        property string tooltipTitle: ""
        property bool hasMenu: false
        property var menu: null
    }
    QtObject {
        id: itemB
        property string title: "Beta"
        property string icon: ""
        property string tooltipTitle: ""
        property bool hasMenu: false
        property var menu: null
    }
    QtObject {
        id: itemC
        property string title: "Gamma"
        property string icon: ""
        property string tooltipTitle: ""
        property bool hasMenu: false
        property var menu: null
    }

    readonly property var fakes: [itemA, itemB, itemC]

    Widgets.Tray {
        id: tray

        width: 400
        height: Lazer.LazerTheme.barWidgetHeight
    }

    // The real delegates, in slot order.
    //
    // Quickshell's Repeater leaves one role-less, zero-width placeholder in
    // `children`; the Row's layout ignores it, so it is filtered out here
    // rather than mistaken for a slot.
    function slots() {
        var row = tray.children[0]
        if (!row)
            return []
        var out = []
        var kids = row.children
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].slotKey !== undefined && kids[i].slotKey !== "")
                out.push(kids[i])
        }
        return out
    }

    // A placeholder that ever picks up a width would inflate the strip.
    function placeholderWidth() {
        var row = tray.children[0]
        if (!row)
            return 0
        var w = 0
        var kids = row.children
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].slotKey === undefined || kids[i].slotKey === "")
                w = Math.max(w, kids[i].width)
        }
        return w
    }

    function slotNamed(label) {
        var s = slots()
        for (var i = 0; i < s.length; i++) {
            if (s[i].label === label)
                return s[i]
        }
        return null
    }

    function retiringCount() {
        var s = slots()
        var n = 0
        for (var i = 0; i < s.length; i++) {
            if (s[i].retiring)
                n++
        }
        return n
    }

    // Every slot must carry a real identity: a delegate whose roles failed to
    // bind would silently occupy a gap with no icon behind it.
    function unnamedSlots() {
        var s = slots()
        var n = 0
        for (var i = 0; i < s.length; i++) {
            if (!s[i].slotKey || !s[i].label)
                n++
        }
        return n
    }
    function settled() {
        var s = slots()
        for (var i = 0; i < s.length; i++) {
            if (s[i].presence < 1 || s[i].ink < 1 || s[i].retiring)
                return false
        }
        return true
    }

    function withFakes() {
        return probe.fakes
    }

    function without(label) {
        var out = []
        for (var i = 0; i < probe.fakes.length; i++) {
            if (probe.fakes[i].title !== label)
                out.push(probe.fakes[i])
        }
        return out
    }

    // Schedule a step `delay` ms from now. Everything is relative to the
    // driver's clock, so a polling step and a marching step can never
    // interleave out of order.
    function after(delay, fn) {
        probe.queue.push({ at: probe.elapsed + delay, fn: fn })
    }

    // Poll `fn` every `every` ms until it reports done or the budget runs out.
    // Poll `sample` every `every` ms until it reports done or the budget runs
    // out, then run `done`. `done` is a separate callback because a step
    // queued with `after(0, …)` would otherwise land *before* the pump's own
    // ticks and read the strip mid-flight.
    function pump(budget, every, sample, done) {
        var started = probe.elapsed
        function tick() {
            if (probe.elapsed - started >= budget || sample()) {
                probe.after(0, done)
                return
            }
            probe.after(every, tick)
        }
        probe.after(every, tick)
    }

    Timer {
        id: driver

        interval: 8
        repeat: true
        running: !probe.done
        onTriggered: {
            probe.elapsed += 8
            while (probe.queue.length > 0 && probe.queue[0].at <= probe.elapsed) {
                var step = probe.queue.shift()
                step.fn()
            }
            if (probe.queue.length === 0 && !probe.done) {
                probe.done = true
                console.log("Totals: " + (probe.failures === 0 ? "0 failed" : probe.failures + " failed"))
                Qt.quit()
            }
        }
    }

    Component.onCompleted: {
        // The service list is swapped out for a synthetic batch: a live desktop
        // must not be able to make these counts drift.
        tray.liveValuesOverride = []
        console.log("session tray items:", (SystemTray.items && SystemTray.items.values)
                ? SystemTray.items.values.length : 0)

        // The widget syncs once before the harness can swap the list, so the
        // session's real icons arrive, then leave. Wait for a warm-up and a
        // stably empty strip: a slot left behind would hold its gap open, and a
        // live desktop that never quiets must not hang the harness.
        function poll() {
            probe.polls++
            if (probe.polls > 8)
                probe.quietPolls = probe.slots().length === 0 ? probe.quietPolls + 1 : 0
            if (probe.quietPolls < 4 && probe.polls < 80)
                probe.after(60, poll)
            else
                probe.after(0, function() {
                    probe.check("startsFromAnEmptyStrip", probe.slots().length === 0,
                            probe.slots().length)
                    probe.runChecks()
                })
        }
        probe.after(60, poll)
    }

    // The phases chain: each one starts from the previous phase's completion,
    // so a check never reads the strip while an earlier phase is still moving.
    function runChecks() {
        phaseArrival()
    }

    function phaseArrival() {
        var t = probe.tokens
        var arrive = t.fast + t.trayIconEnter + 100
        probe.after(20, function() { tray.liveValuesOverride = probe.withFakes() })
        // Sample the whole arrival: the box must always be open before any ink
        // lands in it, and later slots must never be ahead of the first.
        probe.pump(arrive, 16, function() {
            var a = probe.slotNamed("Alpha")
            var c = probe.slotNamed("Gamma")
            if (!a || !c)
                return false
            if (a.presence < 1)
                probe.sawClosedBox = true
            if (a.presence < 1 && a.ink > 0)
                probe.inkBeforeBox++
            if (c.presence > a.presence)
                probe.ghostedSlots++
            return probe.settled()
        }, function() {
            probe.check("batchAddsOneSlotPerItem",
                    !!probe.slotNamed("Alpha") && !!probe.slotNamed("Beta") && !!probe.slotNamed("Gamma"),
                    probe.slots().length)
            probe.check("everySlotCarriesAnIdentity",
                    probe.unnamedSlots() === 0, probe.unnamedSlots())
            probe.check("repeaterPlaceholderStaysOutOfLayout",
                    probe.placeholderWidth() === 0, probe.placeholderWidth())
            probe.check("arrivalOpensTheBoxBeforeTheInk",
                    probe.sawClosedBox && probe.inkBeforeBox === 0, probe.inkBeforeBox)
            probe.check("arrivalCascadesAcrossPositions", probe.ghostedSlots === 0, probe.ghostedSlots)
            probe.check("arrivalSettlesEverySlot", probe.settled(), probe.slots().length)
            probe.check("arrivalWidthMatchesLayout",
                    tray.implicitWidth === probe.settledWidth(tray.liveCount),
                    tray.implicitWidth + " vs " + probe.settledWidth(tray.liveCount))
            probe.after(20, phaseRecipe)
        })
    }

    function phaseRecipe() {
        var t = probe.tokens
        var slot = probe.slotNamed("Alpha")
        probe.check("openUsesFastToken",
                slot.openAnimationItem.duration === t.fast, slot.openAnimationItem.duration)
        probe.check("enterUsesTrayEnterToken",
                slot.enterAnimationItem.duration === t.trayIconEnter, slot.enterAnimationItem.duration)
        probe.check("enterRevealsWithOutQuad",
                slot.enterAnimationItem.easing.type === Easing.OutQuad, slot.enterAnimationItem.easing.type)
        probe.check("exitUsesTrayExitToken",
                slot.exitAnimationItem.duration === t.trayIconExit, slot.exitAnimationItem.duration)
        probe.check("exitInkIsFrontLoaded",
                slot.exitAnimationItem.easing.type === Easing.OutQuad, slot.exitAnimationItem.easing.type)
        probe.check("fallStaysInsideTheBar",
                slot.fallAnimationItem.to === tray.fallDistance
                && tray.fallDistance <= (Lazer.LazerTheme.barWidgetHeight - Lazer.LazerTheme.barGlyphSize) / 2,
                slot.fallAnimationItem.to)
        probe.check("collapseRunsSlowerThanTheInk",
                slot.closeAnimationItem.duration > slot.exitAnimationItem.duration,
                slot.closeAnimationItem.duration)
        probe.check("collapseIsInQuadSoNeighboursWait",
                slot.closeAnimationItem.easing.type === Easing.InQuad, slot.closeAnimationItem.easing.type)
        probe.check("cascadeStepsTwentyFourMs", t.trayIconStagger === 24, t.trayIconStagger)
        probe.after(20, phaseDeparture)
    }

    function phaseDeparture() {
        var t = probe.tokens
        var depart = t.trayIconStagger + t.slow + 100
        var liveBefore = tray.liveCount
        tray.liveValuesOverride = probe.without("Beta")
        probe.after(60, function() {
            var leaving = probe.slotNamed("Beta")
            probe.check("departureKeepsItsSlotResident", !!leaving, "slot gone early")
            probe.check("departureFlagsTheSlot", leaving && leaving.retiring === true, leaving && leaving.retiring)
            probe.check("departureStopsTakingInput", leaving && leaving.enabled === false, leaving && leaving.enabled)
            probe.check("departureLeavesTheLiveSet", tray.liveCount === liveBefore - 1, tray.liveCount)
        })
        // The collapse and the row drop land in the same tick, so their
        // ordering cannot be sampled. Continuity can be: a strip that snapped
        // would jump a whole slot's width in one step, and a collapse that
        // over-shot would dip below the width the survivors settle on.
        var lastWidth = tray.implicitWidth
        var maxStep = 0
        var undershot = false
        probe.pump(depart, 16, function() {
            var width = tray.implicitWidth
            maxStep = Math.max(maxStep, Math.abs(width - lastWidth))
            lastWidth = width
            if (width < probe.settledWidth(tray.liveCount) - 0.5)
                undershot = true
            var leaving = probe.slotNamed("Beta")
            if (!leaving)
                return true
            if (leaving.ink < 0.2 && leaving.fall > 0 && leaving.fall <= tray.fallDistance)
                probe.faded = true
            return false
        }, function() {
            probe.check("departureDropsInkBeforeItLeaves",
                    probe.faded === true, "ink/fall never reached their window")
            // One smooth InQuad collapse over MotionTokens.slow moves at most a
            // few px per 16 ms sample; a row drop that had to finish the job
            // would jump a whole slot.
            probe.check("collapseRunsWithoutASnap", maxStep <= 12, maxStep)
            probe.check("collapseNeverOverShoots", !undershot, "width dipped below the final layout")
            probe.check("departureRemovesTheSlot", probe.slotNamed("Beta") === null,
                    probe.slots().length + " slots")
            probe.check("noResidualAfterRemoval",
                    tray.implicitWidth === probe.settledWidth(tray.liveCount), tray.implicitWidth)
            probe.check("survivorsSettleUnmoved",
                    probe.slotNamed("Alpha").presence === 1 && probe.slotNamed("Alpha").ink === 1
                    && probe.slotNamed("Gamma").presence === 1 && probe.slotNamed("Gamma").ink === 1,
                    "survivor state")
            probe.after(20, phaseRevival)
        })
    }

    function phaseRevival() {
        var t = probe.tokens
        tray.liveValuesOverride = probe.withFakes()
        probe.pump(t.fast + t.trayIconEnter + t.trayIconStagger + 100, 16, function() {
            var back = probe.slotNamed("Beta")
            if (!back)
                return false
            return back.retiring === false && back.presence === 1 && back.ink === 1
        }, function() {
            var back = probe.slotNamed("Beta")
            probe.check("returningItemRevivesItsSlot", !!back, probe.slots().length)
            probe.check("revivedSlotSettles", back && back.retiring === false
                    && back.presence === 1 && back.ink === 1, "revived state")
            probe.check("revivalAddsNoDuplicate",
                    tray.implicitWidth === probe.settledWidth(tray.liveCount), tray.implicitWidth)
            probe.after(20, phaseReducedMotion)
        })
    }

    function phaseReducedMotion() {
        Lazer.MotionTokens.reducedMotionOverride = true
        tray.liveValuesOverride = probe.without("Beta")
        probe.after(60, function() {
            probe.check("reducedMotionSkipsTheExit", probe.slotNamed("Beta") === null,
                    probe.slots().length)
            Lazer.MotionTokens.reducedMotionOverride = false
        })
    }
}
