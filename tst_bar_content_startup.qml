import QtQuick
import "./modules/bar" as Bar

// Startup batching harness for BarContent. Mounts the production component
// with deterministic layout doubles (clock + workspaces + network across
// batches 0/1/2, all backed by the test-only stub widget), stages activation,
// and checks the limit sequence, per-batch loader sets, the readiness gate,
// the single finish emission, batch pacing, and one-way staging.
//
// Offscreen-safe by construction: BarContent and the stub are plain Items, so
// `qs` loads this file headless without mapping a window and without touching
// production widgets or their service side effects. Run from the repo root so
// ./modules resolves inside the config folder:
//   qs -p tst_bar_content_startup.qml
Item {
    id: root
    width: 1280
    height: 48

    property int failures: 0
    property int checks: 0
    // Seeded with the initial limit; every change appends, so a correct run
    // reads 0 -> 1 -> 2 -> 3.
    property var limitSequence: [0]
    // Active loader widget ids per released limit, snapshotted one turn after
    // each change so bindings and synchronous stub loads have settled.
    property var batchSnapshots: ({})
    property bool earlyReadyViolation: false
    property int finishedCount: 0
    property double firstBatchMs: -1
    property double lastBatchMs: -1
    property bool finished: false

    function check(label, condition, detail) {
        root.checks++
        if (condition) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, detail !== undefined ? "| " + detail : "")
    }

    function finish() {
        if (root.finished)
            return
        root.finished = true
        awaitReady.stop()
        giveUp.stop()
        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }

    // Deterministic SettingsService double: hover debug stays silent.
    QtObject {
        id: fakeSettings
        property bool hoverDebugEnabled: false
    }

    // Deterministic BarLayoutService double: one widget per startup batch,
    // every entry backed by the side-effect-free stub (resolved from
    // BarContent's directory, like the production registry sources).
    QtObject {
        id: fakeLayout
        readonly property string stubSource: "../../tests/doubles/StubBarWidget.qml"
        function sectionWidgets(sectionName) {
            if (sectionName === "center")
                return [
                    { id: "workspaces", instanceKey: "workspaces:0",
                      source: fakeLayout.stubSource },
                ]
            if (sectionName === "right")
                return [
                    { id: "clock", instanceKey: "clock:0",
                      source: fakeLayout.stubSource },
                    { id: "network", instanceKey: "network:0",
                      source: fakeLayout.stubSource },
                ]
            return []
        }
    }

    // Production component under test, staged from the first tick.
    Bar.BarContent {
        id: barContent
        width: parent.width
        height: parent.height
        startupStaging: true
        settingsServiceOverride: fakeSettings
        layoutServiceOverride: fakeLayout
    }

    Connections {
        target: barContent
        function onStartupBatchLimitChanged() {
            var limit = barContent.startupBatchLimit
            root.limitSequence.push(limit)
            if (limit === 1 && root.firstBatchMs < 0)
                root.firstBatchMs = Date.now()
            if (limit >= barContent.startupBatchCount)
                root.lastBatchMs = Date.now()
            if (limit <= 1 && barContent.startupReady)
                root.earlyReadyViolation = true
            var captured = limit
            Qt.callLater(function() { root.snapshotBatch(captured) })
        }
        function onStartupFinished() {
            root.finishedCount++
        }
    }

    // Collect every widget Loader in the content tree by capability: only
    // Repeater delegates carry a modelData entry.
    function findLoaders(item, found) {
        var result = found || []
        if (!item)
            return result
        if (item.modelData !== undefined && item.active !== undefined)
            result.push(item)
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++)
                findLoaders(kids[i], result)
        }
        return result
    }

    function activeWidgetIds() {
        var loaders = root.findLoaders(barContent, [])
        var active = []
        for (var i = 0; i < loaders.length; i++) {
            if (loaders[i].active !== true)
                continue
            var id = loaders[i].item ? String(loaders[i].item.widgetId || "")
                    : String(loaders[i].modelData.id || "")
            if (id !== "")
                active.push(id)
        }
        active.sort()
        return active
    }

    function snapshotBatch(limit) {
        // A re-fired limit (which the one-way latch forbids) must not silently
        // overwrite the first observation.
        if (root.batchSnapshots[limit] !== undefined)
            return
        root.batchSnapshots[limit] = root.activeWidgetIds()
    }

    function verify() {
        // The annotation seam clones without reordering: clock (batch 0)
        // precedes network (batch 2) on the right, workspaces (batch 1) is
        // alone in the center.
        var right = barContent.loadableWidgets("right")
        root.check("right section keeps layout order", right.length === 2
                   && right[0].id === "clock" && right[1].id === "network",
                   "got " + JSON.stringify(right.map(function(e) { return e.id })))
        if (right.length === 2) {
            root.check("clock annotated to batch 0", Number(right[0].startupBatch) === 0)
            root.check("network annotated to batch 2", Number(right[1].startupBatch) === 2)
        }
        var center = barContent.loadableWidgets("center")
        root.check("center holds workspaces in batch 1", center.length === 1
                   && center[0].id === "workspaces"
                   && Number(center[0].startupBatch) === 1)

        // Batches release one frame apart from the reset zero.
        var expected = []
        for (var e = 0; e <= barContent.startupBatchCount; e++)
            expected.push(e)
        root.check("batch limits released 0 -> 1 -> 2 -> 3",
                   JSON.stringify(root.limitSequence) === JSON.stringify(expected),
                   "got " + JSON.stringify(root.limitSequence))
        root.check("readiness stayed false through batches 0 and 1",
                   root.earlyReadyViolation === false)
        root.check("startupReady true at the end", barContent.startupReady === true)

        // Each batch activates exactly its own widgets: without the active
        // staging clause every snapshot would hold all three ids instead.
        root.check("limit 1 activates only clock",
                   JSON.stringify(root.batchSnapshots[1]) === JSON.stringify(["clock"]),
                   "got " + JSON.stringify(root.batchSnapshots[1]))
        root.check("limit 2 activates clock and workspaces",
                   JSON.stringify(root.batchSnapshots[2])
                   === JSON.stringify(["clock", "workspaces"]),
                   "got " + JSON.stringify(root.batchSnapshots[2]))
        root.check("limit 3 activates all three widgets",
                   JSON.stringify(root.batchSnapshots[3])
                   === JSON.stringify(["clock", "network", "workspaces"]),
                   "got " + JSON.stringify(root.batchSnapshots[3]))

        // The finish signal fires exactly once.
        root.check("startupFinished emitted exactly once", root.finishedCount === 1,
                   "got " + root.finishedCount)

        // Three 16 ms-spaced batches land far inside a generous ceiling.
        var elapsed = root.lastBatchMs - root.firstBatchMs
        root.check("batches paced one frame apart (< 200 ms)",
                   root.firstBatchMs >= 0 && root.lastBatchMs >= 0 && elapsed < 200,
                   "elapsed=" + elapsed)

        // Every loadable entry eventually activates its loader.
        var loaders = root.findLoaders(barContent, [])
        root.check("three widget loaders mounted", loaders.length === 3,
                   "got " + loaders.length)
        var inactive = 0
        for (var i = 0; i < loaders.length; i++) {
            if (loaders[i].active !== true)
                inactive++
        }
        root.check("every widget loader active", loaders.length === 3 && inactive === 0,
                   inactive + " inactive")

        // One-way staging: switching staging off after completion must not
        // reset the limit, deactivate a widget, or re-emit the finish.
        barContent.startupStaging = false
        Qt.callLater(root.verifyOneWay)
    }

    function verifyOneWay() {
        root.check("staging off keeps the released limit",
                   barContent.startupBatchLimit === barContent.startupBatchCount,
                   "limit=" + barContent.startupBatchLimit)
        root.check("staging off keeps readiness", barContent.startupReady === true)
        root.check("staging off keeps every loader active",
                   JSON.stringify(root.activeWidgetIds())
                   === JSON.stringify(["clock", "network", "workspaces"]),
                   "got " + JSON.stringify(root.activeWidgetIds()))
        root.check("staging off emits no second finish", root.finishedCount === 1,
                   "got " + root.finishedCount)
        root.finish()
    }

    Timer {
        id: awaitReady
        interval: 30
        repeat: true
        onTriggered: {
            if (barContent.startupReady && !root.finished)
                root.verify()
        }
    }

    // A ceiling, so a batch that never releases reports instead of hanging
    // until the runner's own timeout.
    Timer {
        id: giveUp
        interval: 10000
        repeat: false
        onTriggered: {
            root.check("startup batches released", false,
                       "limit=" + barContent.startupBatchLimit
                       + " ready=" + barContent.startupReady
                       + " sequence=" + JSON.stringify(root.limitSequence))
            root.finish()
        }
    }

    Component.onCompleted: {
        awaitReady.restart()
        giveUp.restart()
    }
}
