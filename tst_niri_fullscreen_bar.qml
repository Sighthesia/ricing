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
        function() { root.checkCurrentVerdictMatchesLiveGeometry() },
        function() { root.checkRealFullscreenGeometry() },
        function() { root.checkSyntheticFullscreen() },
        function() { root.checkBindingTracksServiceState() },
        function() { root.checkLeavingFullscreenClearsTheVerdict() },
        function() { root.checkStaleBackgroundGeometryCannotPinTheBar() },
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

    // Cross-check the verdict against the live geometry rather than assuming a
    // fixed answer: the user may well have a fullscreen window open right now,
    // and a harness that insisted on `false` would be asserting the harness's
    // own schedule rather than the code's behaviour.
    function checkCurrentVerdictMatchesLiveGeometry() {
        const name = root.activeOutputName()
        if (!name) {
            root.ok(false, "found an active output to check the live verdict against")
            return
        }
        const size = Services.NiriService.outputSizes[name] || {}
        const ws = root.activeWorkspaceId(name)
        const scale = Number(size.scale) || 1
        const slack = 3 / scale + 0.5

        let expected = false
        let sawActiveWindow = false
        for (let i = 0; i < Services.NiriService.windows.count; i++) {
            const win = Services.NiriService.windows.get(i)
            if (String(win.workspaceId) !== String(ws))
                continue
            sawActiveWindow = true
            if (Math.abs(win.tileWidth - size.width) <= slack
                    && Math.abs(win.tileHeight - size.height) <= slack)
                expected = true
        }
        root.ok(sawActiveWindow, "the active workspace has a window to judge")
        root.compare(
            Services.NiriService.isOutputFullscreen(name), expected,
            "live verdict matches the live geometry (expected " + expected + ")")
    }

    // The regression that shipped broken: a real fullscreen tile on a 1.75 panel
    // measures 1646.29x1029.14 while the IPC publishes the output as 1645x1028,
    // so a 1px slack missed it by 0.29 and the bar never collapsed. Replay the
    // exact numbers niri reported and require the verdict to be true.
    function checkRealFullscreenGeometry() {
        const name = root.activeOutputName()
        if (!name) {
            root.ok(false, "found an active output to replay real geometry against")
            return
        }
        const size = Services.NiriService.outputSizes[name] || {}
        const ws = root.activeWorkspaceId(name)
        const realWindows = Services.NiriService.windows
        const snapshot = []
        for (let i = 0; i < realWindows.count; i++)
            snapshot.push(realWindows.get(i))

        realWindows.clear()
        realWindows.append({
            winId: "888888", title: "measured fullscreen", appId: "harness",
            isFocused: true, workspaceId: ws, colIdx: 1, rowIdx: 1,
            // Measured on eDP-1 (2880x1800 @1.75), not synthesised from the
            // published output size.
            tileWidth: 1646.2857142857142,
            tileHeight: 1029.142857142857
        })
        Services.NiriService.recomputeFullscreenOutputs()
        root.ok(Services.NiriService.isOutputFullscreen(name),
            "real measured fullscreen tile is detected at scale "
                + size.scale + " (ipc output " + size.width + "x" + size.height + ")")

        // And the ordinary tiled size seen in the same live session must not be.
        realWindows.setProperty(0, "tileWidth", 1614.2857142857142)
        realWindows.setProperty(0, "tileHeight", 949.142857142857)
        Services.NiriService.recomputeFullscreenOutputs()
        root.compare(
            Services.NiriService.isOutputFullscreen(name), false,
            "the live tiled size is still not fullscreen")

        realWindows.clear()
        for (let i = 0; i < snapshot.length; i++)
            realWindows.append(snapshot[i])
        Services.NiriService.recomputeFullscreenOutputs()
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

        // A gap short of the output must stay a normal window. The margin has to
        // clear the scale-derived slack (2.21px at 1.75), so use a real gap.
        realWindows.setProperty(0, "tileWidth", Number(size.width) - 16)
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

    // A QML binding that only calls a service FUNCTION has no tracked
    // dependency, so it evaluates once and never invalidates — the bar would
    // then never learn that a fullscreen window appeared. This mirrors the
    // bar's own binding shape and proves it re-evaluates when the service
    // changes underneath it.
    Item {
        id: probe
        readonly property bool viaFunction: Services.NiriService
                .isOutputFullscreen(probe.outputName)
        readonly property bool viaMap:
                (Services.NiriService.fullscreenOutputs || {})[probe.outputName] === true
        property string outputName: ""
    }

    function checkBindingTracksServiceState() {
        const name = root.activeOutputName()
        if (!name) {
            root.ok(false, "found an active output to test the binding against")
            return
        }
        probe.outputName = name
        root.compare(probe.viaFunction, false, "binding starts false (no fullscreen)")
        root.compare(probe.viaMap, false, "map binding starts false (no fullscreen)")

        const size = Services.NiriService.outputSizes[name] || {}
        const ws = root.activeWorkspaceId(name)
        const realWindows = Services.NiriService.windows
        realWindows.clear()
        realWindows.append({
            winId: "999999", title: "synthetic", appId: "harness", isFocused: true,
            workspaceId: ws, colIdx: 1, rowIdx: 1,
            tileWidth: Number(size.width), tileHeight: Number(size.height)
        })
        Services.NiriService.recomputeFullscreenOutputs()

        root.compare(probe.viaMap, true, "map binding follows the service")
        root.compare(probe.viaFunction, true, "function binding follows the service")
    }

    // niri reports geometry-only changes through WindowLayoutsChanged, and
    // leaving fullscreen is geometry-only. Replay the real sequence — enter
    // fullscreen, then leave it via a layout event alone — and require the
    // verdict to come back false. This is the regression that shipped: the
    // service ignored the event, so the verdict stuck at `true` and the bar
    // stayed collapsed until a workspace switch forced a full re-pull.
    function checkLeavingFullscreenClearsTheVerdict() {
        const name = root.activeOutputName()
        const ws = root.activeWorkspaceId(name)
        if (!name || !ws) {
            root.ok(false, "found an active workspace to replay the exit against")
            return
        }
        const size = Services.NiriService.outputSizes[name] || {}
        const realWindows = Services.NiriService.windows
        const snapshot = []
        for (let i = 0; i < realWindows.count; i++)
            snapshot.push(realWindows.get(i))

        // Enter fullscreen, the way a real session would report it.
        realWindows.clear()
        realWindows.append({
            winId: "777777", title: "exiting", appId: "harness", isFocused: true,
            workspaceId: ws, colIdx: 1, rowIdx: 1,
            tileWidth: 1646.2857142857142, tileHeight: 1029.142857142857
        })
        Services.NiriService.recomputeFullscreenOutputs()
        root.ok(Services.NiriService.isOutputFullscreen(name), "entered fullscreen")

        // Leave fullscreen. niri sends ONLY WindowLayoutsChanged for this.
        Services.NiriService.updateWindowLayouts([
            [777777, {
                tile_size: [1614.2857142857142, 949.142857142857],
                window_size: [1606, 941],
                window_offset_in_tile: [4, 4]
            }]
        ])
        root.compare(
            Services.NiriService.isOutputFullscreen(name), false,
            "leaving fullscreen clears the verdict from a layout event alone")

        // And back in, through a layout event, to prove the round trip holds.
        Services.NiriService.updateWindowLayouts([
            [777777, {
                tile_size: [1646.2857142857142, 1029.142857142857],
                window_size: [1646, 1029],
                window_offset_in_tile: [0, 0]
            }]
        ])
        root.ok(
            Services.NiriService.isOutputFullscreen(name),
            "re-entering fullscreen through a layout event works again")

        // A layout event for an unknown window must not corrupt the verdict.
        Services.NiriService.updateWindowLayouts([
            [424242, { tile_size: [10, 10], window_size: [10, 10] }]
        ])
        root.ok(
            Services.NiriService.isOutputFullscreen(name),
            "a layout event for an unknown window leaves state intact")

        // Malformed entries must be ignored, not crash or misjudge.
        Services.NiriService.updateWindowLayouts([
            null, [], [777777], [777777, {}], [777777, { tile_size: null }],
            "not-a-pair", [777777, { tile_size: [1] }]
        ])
        root.ok(
            Services.NiriService.isOutputFullscreen(name),
            "malformed layout entries are ignored without corrupting state")
        Services.NiriService.updateWindowLayouts(null)
        Services.NiriService.updateWindowLayouts([])

        realWindows.clear()
        for (let i = 0; i < snapshot.length; i++)
            realWindows.append(snapshot[i])
        Services.NiriService.recomputeFullscreenOutputs()
    }

    // The bug the live probe caught: verdicts said fullscreen while the covering
    // window was an ordinary tiled firefox. A backgrounded window kept its stale
    // fullscreen geometry and the "any window looks fullscreen" scan believed it.
    // Replay exactly that shape against the real service.
    function checkStaleBackgroundGeometryCannotPinTheBar() {
        const name = root.activeOutputName()
        const ws = root.activeWorkspaceId(name)
        if (!name || !ws) {
            root.ok(false, "found an active workspace to replay stale geometry against")
            return
        }
        const realWindows = Services.NiriService.windows
        const snapshot = []
        for (let i = 0; i < realWindows.count; i++)
            snapshot.push(realWindows.get(i))

        realWindows.clear()
        // A window that was fullscreen and then unfullscreened, left behind with
        // its old geometry and no longer focused.
        realWindows.append({
            winId: "555", title: "stale fullscreen", appId: "harness",
            isFocused: false, workspaceId: ws, colIdx: 1, rowIdx: 1,
            tileWidth: 1646.2857142857142, tileHeight: 1029.142857142857
        })
        // The window actually in front: plainly tiled, like the firefox in the
        // live probe.
        realWindows.append({
            winId: "556", title: "front", appId: "firefox",
            isFocused: true, workspaceId: ws, colIdx: 2, rowIdx: 1,
            tileWidth: 1614.2857142857142, tileHeight: 949.142857142857
        })
        Services.NiriService.recomputeFullscreenOutputs()
        root.compare(
            Services.NiriService.isOutputFullscreen(name), false,
            "stale background fullscreen geometry does not pin the bar")

        // Focus landing on the stale one must make it count, proving the check is
        // about focus rather than about the geometry being present.
        realWindows.setProperty(0, "isFocused", true)
        realWindows.setProperty(1, "isFocused", false)
        Services.NiriService.recomputeFullscreenOutputs()
        root.ok(
            Services.NiriService.isOutputFullscreen(name),
            "the same geometry counts once it is the focused window")

        // And focus moving back off it must clear it again.
        realWindows.setProperty(0, "isFocused", false)
        realWindows.setProperty(1, "isFocused", true)
        Services.NiriService.recomputeFullscreenOutputs()
        root.compare(
            Services.NiriService.isOutputFullscreen(name), false,
            "moving focus off the fullscreen window brings the bar back")

        realWindows.clear()
        for (let i = 0; i < snapshot.length; i++)
            realWindows.append(snapshot[i])
        Services.NiriService.recomputeFullscreenOutputs()
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
