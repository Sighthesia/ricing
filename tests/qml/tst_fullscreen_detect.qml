import QtQuick
import QtTest
import "../../services/FullscreenDetect.js" as Detect

Item {
    TestCase {
        name: "FullscreenDetect"

        // eDP-1 is 1645x1028 at scale 1.75; the bar reserves 48px of it, so the
        // working area (a maximized window) is 1645x980 before gaps.
        readonly property var screen: "eDP-1"
        // Real measured values from eDP-1: a 2880x1800 panel at scale 1.75. niri
        // publishes logical extents as the integers 1645x1028, but a fullscreen
        // tile is sized in f64 and rounded to a physical pixel, so it actually
        // measures 1646.286x1029.143 — a physical-pixel step PAST the IPC size.
        readonly property var sizes: ({ "eDP-1": { width: 1645, height: 1028, scale: 1.75 } })
        readonly property real measuredFullscreenW: 1646.2857142857142
        readonly property real measuredFullscreenH: 1029.142857142857

        function window(workspaceId, tileWidth, tileHeight, winId, focused) {
            return {
                winId: winId === undefined ? String(tileWidth) + "x" + tileHeight : winId,
                workspaceId: workspaceId,
                isFocused: focused === true,
                tileWidth: tileWidth,
                tileHeight: tileHeight
            }
        }

        // The verdict for the only window on a focused workspace, which is the
        // usual single-window case and needs no separate focus event.
        function soleWindowVerdict(ws, tileWidth, tileHeight) {
            return Detect.fullscreenOutputs(sizes, { "eDP-1": ws },
                { "eDP-1": "sole" }, [window(ws, tileWidth, tileHeight, "sole", true)])["eDP-1"]
        }

        function test_fullscreenTileCoversWholeOutput() {
            verify(Detect.coversOutput(1645, 1028, 1645, 1028))
        }

        function test_maximizedTileIsNotFullscreen() {
            // Working area height only: the bar's exclusive zone is reserved.
            verify(!Detect.coversOutput(1645, 980, 1645, 1028))
        }

        function test_normalTiledWindowIsNotFullscreen() {
            // A four-column tile with gaps and borders: far short in both axes.
            verify(!Detect.coversOutput(403, 949, 1645, 1028))
        }

        function test_detectsTheRealMeasuredFullscreenTile() {
            // The exact tile size niri reported for a real fullscreen window.
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" },
                { "eDP-1": "fs" },
                [window("1", measuredFullscreenW, measuredFullscreenH, "fs", true)])
            compare(result["eDP-1"], true)
        }

        function test_slackScalesWithTheOutput() {
            // A 0.5-scaled output rounds tile geometry in coarser logical steps,
            // so a fixed 1px slack would miss fullscreen there entirely.
            var half = ({ "OUT": { width: 1440, height: 900, scale: 0.5 } })
            compare(Detect.fullscreenOutputs(half, { "OUT": "1" }, { "OUT": "w" },
                [window("1", 1442, 902, "w", true)])["OUT"], true)
            // An integer-scaled output needs only a little.
            var whole = ({ "OUT": { width: 1440, height: 900, scale: 1 } })
            compare(Detect.fullscreenOutputs(whole, { "OUT": "1" }, { "OUT": "w" },
                [window("1", 1440, 900, "w", true)])["OUT"], true)
            compare(Detect.fullscreenOutputs(whole, { "OUT": "1" }, { "OUT": "w" },
                [window("1", 1436, 900, "w", true)])["OUT"], false)
        }

        function test_slackStaysWellBelowTheGapThatMatters() {
            // At every realistic scale the slack must stay far below niri's 16px
            // gaps, or an ordinary tiled window could read as fullscreen.
            var scales = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3]
            for (var i = 0; i < scales.length; i++)
                verify(Detect.slackForScale(scales[i]) < 8,
                    "slack stays under 8px at scale " + scales[i])
            // The real measured tile minus one gap is a normal window.
            compare(soleWindowVerdict("1", measuredFullscreenW, measuredFullscreenH - 16),
                false)
        }

        function test_explicitSlackOverridesTheScale() {
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, { "eDP-1": "w" },
                [window("1", measuredFullscreenW, measuredFullscreenH, "w", true)], 0)
            compare(result["eDP-1"], false)
        }

        function test_invalidSizesNeverReportFullscreen() {
            verify(!Detect.coversOutput(0, 1028, 1645, 1028))
            verify(!Detect.coversOutput(1645, 0, 1645, 1028))
            verify(!Detect.coversOutput(NaN, 1028, 1645, 1028))
            verify(!Detect.coversOutput(1645, 1028, 0, 1028))
            verify(!Detect.coversOutput(1645, 1028, undefined, undefined))
            verify(!Detect.coversOutput(null, null, null, null))
        }

        function test_singleAxeMatchIsNotFullscreen() {
            verify(!Detect.coversOutput(1645, 980, 1645, 1028))
            verify(!Detect.coversOutput(1614, 1028, 1645, 1028))
        }

        function test_onePixelSlackStillAppliesWhenPassedExplicitly() {
            verify(Detect.coversOutput(1644, 1029, 1645, 1028, 1))
            verify(!Detect.coversOutput(1643, 1028, 1645, 1028, 1))
        }

        function test_activeWorkspaceFullscreenMarksItsOutput() {
            compare(soleWindowVerdict("1", 1645, 1028), true)
        }

        function test_windowOnBackgroundWorkspaceIsIgnored() {
            // A fullscreen window on a workspace the output is not showing must
            // not collapse that output's bar.
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "2" }, { "eDP-1": "w" },
                [window("7", 1645, 1028, "w", true)])
            compare(result["eDP-1"], false)
        }

        function test_outputWithoutActiveWorkspaceIsNotFullscreen() {
            var result = Detect.fullscreenOutputs(sizes, {}, { "eDP-1": "w" },
                [window("2", 1645, 1028, "w", true)])
            compare(result["eDP-1"], false)
        }

        function test_anyFullscreenWindowOnTheActiveWorkspaceCounts() {
            // The FOCUSED window is fullscreen; its neighbours are not.
            var windows = [
                window("2", 403, 949, "a", false),
                window("2", 1614, 980, "b", false),
                window("2", 1645, 1028, "c", true)
            ]
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "2" }, { "eDP-1": "c" }, windows)
            compare(result["eDP-1"], true)
        }

        // The regression found with the live probe: a fullscreen window that
        // unfullscreened, or that merely lost focus, kept its fullscreen-sized
        // geometry in the model. Scanning for "any fullscreen-sized window"
        // reported true over a plainly tiled firefox and pinned the bar
        // collapsed. Only the focused window may decide.
        function test_unfocusedStaleFullscreenGeometryDoesNotCount() {
            var windows = [
                // Stale fullscreen geometry, backgrounded.
                window("1", measuredFullscreenW, measuredFullscreenH, "stale", false),
                // The window actually in front, plainly tiled.
                window("1", 1614.2857, 949.1429, "front", true)
            ]
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, { "eDP-1": "front" }, windows)
            compare(result["eDP-1"], false)
        }

        function test_focusMovingOffAFullscreenWindowClearsTheVerdict() {
            var windows = [
                window("1", measuredFullscreenW, measuredFullscreenH, "fs", true),
                window("1", 1614.2857, 949.1429, "other", false)
            ]
            compare(Detect.fullscreenOutputs(sizes, { "eDP-1": "1" },
                { "eDP-1": "fs" }, windows)["eDP-1"], true)
            // Same geometry, focus moved away: the bar must come back.
            windows[0].isFocused = false
            windows[1].isFocused = true
            compare(Detect.fullscreenOutputs(sizes, { "eDP-1": "1" },
                { "eDP-1": "other" }, windows)["eDP-1"], false)
        }

        function test_fullscreenCountsWithoutAFocusSignal() {
            // A focus event can name a window the model has not caught up with
            // yet. The isFocused flag alone must be enough.
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, null,
                [window("1", measuredFullscreenW, measuredFullscreenH, "fs", true)])
            compare(result["eDP-1"], true)
        }

        function test_soleWindowCountsWhenNoWindowIsFocused() {
            // Nothing focused at all (e.g. a layer surface has focus). The single
            // window on screen is still the one the user is looking at.
            compare(soleWindowVerdict("1", measuredFullscreenW, measuredFullscreenH), true)
            compare(soleWindowVerdict("1", 1614.2857, 949.1429), false)
        }

        function test_nothingFocusedOnAMultiWindowWorkspaceIsNotFullscreen() {
            // With several windows and no focus signal there is no basis to judge
            // one of them, so do not collapse.
            var windows = [
                window("1", measuredFullscreenW, measuredFullscreenH, "a", false),
                window("1", 1614.2857, 949.1429, "b", false)
            ]
            compare(Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, null, windows)["eDP-1"],
                false)
        }

        function test_focusPointingAtAMissingWindowFallsBack() {
            // Focus names a window that is gone; a single remaining window is
            // still the visible one.
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, { "eDP-1": "gone" },
                [window("1", measuredFullscreenW, measuredFullscreenH, "real", false)])
            compare(result["eDP-1"], true)
        }

        function test_outputsAreTrackedIndependently() {
            var sizes = {
                "eDP-1": { width: 1645, height: 1028 },
                "DP-1": { width: 2560, height: 1440 }
            }
            var windows = [
                window("1", 1614.2857, 949.1429, "a", false),
                window("2", 2560, 1440, "b", true)
            ]
            var result = Detect.fullscreenOutputs(sizes, {
                "eDP-1": "1",
                "DP-1": "2"
            }, { "eDP-1": "a", "DP-1": "b" }, windows)
            compare(result["eDP-1"], false)
            compare(result["DP-1"], true)
        }

        function test_workspaceIdsCompareAsStrings() {
            // niri reports numeric ids; the model stores them as strings.
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": 2 }, { "eDP-1": 7 },
                [window("2", 1645, 1028, 7, true)])
            compare(result["eDP-1"], true)
        }

        function test_emptyInputsAreSafe() {
            compare(Detect.fullscreenOutputs({}, {}, {}, []), {})
            compare(Detect.fullscreenOutputs(null, null, null, null), {})
            compare(Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, {}, []),
                ({ "eDP-1": false }))
            // A window row missing geometry must not throw or match.
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, { "eDP-1": "x" },
                [null, {}])
            compare(result["eDP-1"], false)
        }

        function test_unknownOutputSizeIsSkipped() {
            // An output whose logical size never arrived must not appear in the
            // result at all, so no bar collapses on missing data.
            var result = Detect.fullscreenOutputs(
                { "eDP-1": { width: 0, height: 1028 } }, { "eDP-1": "1" },
                { "eDP-1": "w" }, [window("1", 1645, 1028, "w", true)])
            compare(result["eDP-1"], undefined)
            compare(Object.keys(result).length, 0)
        }
    }
}
