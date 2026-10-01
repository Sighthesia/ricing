import QtQuick
import "./modules/bar" as Bar

// Startup batching harness for BarContent. Mounts the production component
// with deterministic layout doubles (clock + workspaces + network across
// batches 0/1/2), stages activation, and checks the limit sequence, the
// readiness gate, and eventual loader activation.
//
// Offscreen-safe by construction: BarContent and the three widgets under test
// are plain Items, so `qs` loads this file headless without mapping a window.
// Run from the repo root so ./modules resolves inside the config folder:
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
    property bool earlyReadyViolation: false
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

    // Deterministic BarLayoutService double: one widget per startup batch.
    QtObject {
        id: fakeLayout
        function sectionWidgets(sectionName) {
            if (sectionName === "center")
                return [
                    { id: "workspaces", instanceKey: "workspaces:0",
                      source: "../../modules/bar/widgets/Workspaces.qml" },
                ]
            if (sectionName === "right")
                return [
                    { id: "clock", instanceKey: "clock:0",
                      source: "../../modules/bar/widgets/Clock.qml" },
                    { id: "network", instanceKey: "network:0",
                      source: "../../modules/bar/widgets/Network.qml" },
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
            root.limitSequence.push(barContent.startupBatchLimit)
            if (barContent.startupBatchLimit <= 1 && barContent.startupReady)
                root.earlyReadyViolation = true
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
        root.check("batch limits released 0 -> 1 -> 2 -> 3",
                   JSON.stringify(root.limitSequence) === JSON.stringify([0, 1, 2, 3]),
                   "got " + JSON.stringify(root.limitSequence))
        root.check("readiness stayed false through batches 0 and 1",
                   root.earlyReadyViolation === false)
        root.check("startupReady true at the end", barContent.startupReady === true)

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
        root.finish()
    }

    Timer {
        id: awaitReady
        interval: 30
        repeat: true
        onTriggered: {
            if (barContent.startupReady)
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
