import QtQuick
import QtTest
import "../../services/FullscreenDetect.js" as Detect

Item {
    TestCase {
        name: "FullscreenDetect"

        // eDP-1 is 1645x1028 at scale 1.75; the bar reserves 48px of it, so the
        // working area (a maximized window) is 1645x980 before gaps.
        readonly property var screen: "eDP-1"
        readonly property var sizes: ({ "eDP-1": { width: 1645, height: 1028 } })

        function window(workspaceId, tileWidth, tileHeight) {
            return { workspaceId: workspaceId, tileWidth: tileWidth, tileHeight: tileHeight }
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

        function test_onePixelSlackAbsorbsFractionalScaleRounding() {
            verify(Detect.coversOutput(1644, 1029, 1645, 1028))
            verify(!Detect.coversOutput(1643, 1028, 1645, 1028))
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

        function test_activeWorkspaceFullscreenMarksItsOutput() {
            var windows = [window("1", 1645, 1028)]
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, windows)
            compare(result["eDP-1"], true)
        }

        function test_windowOnBackgroundWorkspaceIsIgnored() {
            // A fullscreen window on a workspace the output is not showing must
            // not collapse that output's bar.
            var windows = [window("7", 1645, 1028)]
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "2" }, windows)
            compare(result["eDP-1"], false)
        }

        function test_outputWithoutActiveWorkspaceIsNotFullscreen() {
            var windows = [window("2", 1645, 1028)]
            var result = Detect.fullscreenOutputs(sizes, {}, windows)
            compare(result["eDP-1"], false)
        }

        function test_anyFullscreenWindowOnTheActiveWorkspaceCounts() {
            var windows = [
                window("2", 403, 949),
                window("2", 1614, 980),
                window("2", 1645, 1028)
            ]
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "2" }, windows)
            compare(result["eDP-1"], true)
        }

        function test_outputsAreTrackedIndependently() {
            var sizes = {
                "eDP-1": { width: 1645, height: 1028 },
                "DP-1": { width: 2560, height: 1440 }
            }
            var windows = [window("2", 2560, 1440)]
            var result = Detect.fullscreenOutputs(sizes, {
                "eDP-1": "1",
                "DP-1": "2"
            }, windows)
            compare(result["eDP-1"], false)
            compare(result["DP-1"], true)
        }

        function test_workspaceIdsCompareAsStrings() {
            // niri reports numeric ids; the model stores them as strings.
            var windows = [window("2", 1645, 1028)]
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": 2 }, windows)
            compare(result["eDP-1"], true)
        }

        function test_emptyInputsAreSafe() {
            compare(Detect.fullscreenOutputs({}, {}, []), {})
            compare(Detect.fullscreenOutputs(null, null, null), {})
            compare(Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, []), ({ "eDP-1": false }))
            // A window row missing geometry must not throw or match.
            var result = Detect.fullscreenOutputs(sizes, { "eDP-1": "1" }, [null, {}])
            compare(result["eDP-1"], false)
        }

        function test_unknownOutputSizeIsSkipped() {
            // An output whose logical size never arrived must not appear in the
            // result at all, so no bar collapses on missing data.
            var result = Detect.fullscreenOutputs(
                { "eDP-1": { width: 0, height: 1028 } }, { "eDP-1": "1" }, [window("1", 1645, 1028)])
            compare(result["eDP-1"], undefined)
            compare(Object.keys(result).length, 0)
        }
    }
}
