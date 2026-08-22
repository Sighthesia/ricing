import QtQuick
import QtTest
import "../../modules/lazerbar/OverlayCoordinatorLogic.js" as Logic

// Verify target validation and visual-owner classification without loading QML surfaces.
TestCase {
    name: "OverlayCoordinatorLogic"

    function test_targetClassification() {
        compare(Logic.normalizeTarget("launcher"), "launcher")
        compare(Logic.normalizeTarget("remote"), "")
        compare(Logic.ownerFor("launcher"), "wave")
        compare(Logic.ownerFor("settings"), "settings")
        compare(Logic.ownerFor("music"), "music")
        compare(Logic.ownerFor("remote"), "")
    }

    function test_deprecatedWaveTargetsAreRejected() {
        compare(Logic.normalizeTarget("wiki"), "")
        compare(Logic.normalizeTarget("news"), "")
        compare(Logic.normalizeTarget("beatmap"), "")
        compare(Logic.ownerFor("wiki"), "")
        compare(Logic.ownerFor("news"), "")
        compare(Logic.ownerFor("beatmap"), "")
    }

    function test_ownerPairsAreDistinctOwners() {
        verify(Logic.ownerFor("launcher") !== Logic.ownerFor("settings"))
        verify(Logic.ownerFor("launcher") !== Logic.ownerFor("music"))
        verify(Logic.ownerFor("settings") !== Logic.ownerFor("music"))
    }
}
