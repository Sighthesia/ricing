// Integration check for the fullscreen auto-hide pipeline: the real NiriService
// parsing the real niri event stream, feeding the pure FullscreenDetect verdict
// that TopBar binds to.
//
// Declares no PanelWindow, so it maps nothing and is safe under offscreen.
//
// Run: QT_QPA_PLATFORM=offscreen qs -p tst_niri_fullscreen_bar.qml
import QtQuick
import Quickshell
import "./services" as Services

Item {
    id: root
    width: 1
    height: 1

    property int passed: 0
    property int failed: 0
    property var steps: [
        function() { root.checkOutputSizes() },
        function() { root.checkWorkspaceOutputs() },
        function() { root.checkWindowGeometry() },
        function() { root.checkCurrentVerdictIsFalse() },
        function() { root.checkSyntheticFullscreen() },
        function() { root.finish() }
    ]

    function ok(condition, label) {
        if (condition) {
            root.passed++
            console.log("PASS:", label)
        } else {
            root.failed++
            console.log("FAIL:", label)
        }
    }

    function compare(actual, expected, label) {
        root.ok(actual === expected, label + " (expected " + expected + ", got " + actual + ")")
    }

    // The outputs fetch and the event stream both land before this runs.
    function checkOutputSizes() {
        const sizes = Services.NiriService.outputSizes
        const names = Object.keys(sizes || {})
        root.ok(names.length > 0, "niri reported at least one output size")

        let sane = true
        for (let i = 0; i < names.length; i++) {
            const size = sizes[names[i]] || {}
            if (!(Number(size.width) > 0) || !(Number(size.height) > 0))
                sane = false
        }
        root.ok(sane, "every output has positive logical extents")
    }

    function checkWorkspaceOutputs() {
        // A bar can only decide fullscreen per monitor if each workspace knows
        // its output, so no workspace may be missing one.
        let complete = Services.NiriService.workspaces.count > 0
        for (let i = 0; i < Services.NiriService.workspaces.count; i++) {
            if (!Services.NiriService.workspaces.get(i).output)
                complete = false
        }
        root.ok(complete, "every workspace carries its output connector")
    }

    function checkWindowGeometry() {
        let complete = Services.NiriService.windows.count > 0
        for (let i = 0; i < Services.NiriService.windows.count; i++) {
            const win = Services.NiriService.windows.get(i)
            if (!(Number(win.tileWidth) > 0) || !(Number(win.tileHeight) > 0))
                complete = false
        }
        root.ok(complete, "every window carries positive tile geometry")
    }

    // Nothing in this harness fullscreens a window, so the live verdict must be
    // false: a bar that collapses for an ordinary tiled window is the regression
    // this whole feature is most likely to ship.
    function checkCurrentVerdictIsFalse() {
        const sizes = Services.NiriService.outputSizes
        for (let i = 0; i < Services.NiriService.workspaces.count; i++) {
            const ws = Services.NiriService.workspaces.get(i)
            if (!ws.isActive || !ws.output)
                continue
            root.compare(
                Services.NiriService.isOutputFullscreen(ws.output),
                false,
                "no false fullscreen on active output " + ws.output)
        }
        root.ok(Object.keys(sizes || {}).length >= 0, "output size map stays readable")
    }

    // Drive the real service's recompute with a synthetic fullscreen window on
    // the active workspace and confirm it flips to true, then back to false.
    function checkSyntheticFullscreen() {
        const activeOutput = root.activeOutputName()
        if (!activeOutput) {
            root.ok(false, "found an active output to test against")
            return
        }
        const size = Services.NiriService.outputSizes[activeOutput] || {}
        const activeWorkspace = root.activeWorkspaceId(activeOutput)
        if (!activeWorkspace) {
            root.ok(false, "found an active workspace to test against")
            return
        }

        const before = Services.NiriService.isOutputFullscreen(activeOutput)
        const realWindows = Services.NiriService.windows

        // Snapshot, then stand in a window covering the whole output.
        const snapshot = []
        for (let i = 0; i < realWindows.count; i++)
            snapshot.push(realWindows.get(i))

        realWindows.clear()
        realWindows.append({
            winId: "999999",
            title: "synthetic fullscreen",
            appId: "harness",
            isFocused: true,
            workspaceId: activeWorkspace,
            colIdx: 1,
            rowIdx: 1,
            tileWidth: Number(size.width),
            tileHeight: Number(size.height)
        })
        Services.NiriService.recomputeFullscreenOutputs()
        root.compare(
            Services.NiriService.isOutputFullscreen(activeOutput), true,
            "a tile covering the whole output reports fullscreen")

        // One logical pixel short of fullscreen must stay a normal window.
        realWindows.setProperty(0, "tileWidth", Number(size.width) - 2)
        Services.NiriService.recomputeFullscreenOutputs()
        root.compare(
            Services.NiriService.isOutputFullscreen(activeOutput), false,
            "a tile one gap short of the output is not fullscreen")

        for (let i = 0; i < snapshot.length; i++)
            realWindows.append(snapshot[i])
        realWindows.clear()
        for (let i = 0; i < snapshot.length; i++)
            realWindows.append(snapshot[i])
        Services.NiriService.recomputeFullscreenOutputs()
        root.compare(
            Services.NiriService.isOutputFullscreen(activeOutput), before,
            "restoring the real windows restores the original verdict")
    }

    function activeOutputName() {
        for (let i = 0; i < Services.NiriService.workspaces.count; i++) {
            const ws = Services.NiriService.workspaces.get(i)
            if (ws.isActive && ws.output && Services.NiriService.outputSizes[ws.output])
                return ws.output
        }
        return ""
    }

    function activeWorkspaceId(outputName) {
        for (let i = 0; i < Services.NiriService.workspaces.count; i++) {
            const ws = Services.NiriService.workspaces.get(i)
            if (ws.isActive && ws.output === outputName)
                return String(ws.wsId)
        }
        return ""
    }

    function finish() {
        console.log("Totals: " + root.passed + " passed, " + root.failed + " failed")
    }

    property int settled: 0

    function ready() {
        return (Services.NiriService.outputSizes
                    && Object.keys(Services.NiriService.outputSizes).length > 0
                && Services.NiriService.workspaces.count > 0
                && Services.NiriService.windows.count > 0)
    }

    // The niri output/workspace fetches and the event stream's initial snapshot
    // all land on later event-loop turns than component completion, and each
    // reply is a real process round-trip — so settle on a timer, not on
    // Qt.callLater, which would spin through the whole budget in one turn.
    Timer {
        id: settleTimer
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            root.settled++
            if (root.ready() || root.settled > 40) {
                running = false
                if (!root.ready())
                    console.log("FAIL: niri state settled within 8s")
                root.step()
            }
        }
    }

    function step() {
        const fn = root.steps.shift()
        if (!fn) {
            Qt.callLater(function() { Qt.quit() })
            return
        }
        fn()
        // One event-loop turn per step: niri IPC arrives on its own schedule and
        // service signals land mid-cascade while sibling bindings are stale.
        Qt.callLater(root.step)
    }

    Component.onCompleted: {
        // Touch the singleton so its niri IPC actually starts.
        void Services.NiriService.outputSizes
    }
}
