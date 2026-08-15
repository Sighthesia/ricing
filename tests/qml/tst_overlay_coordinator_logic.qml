import QtQuick
import QtTest
import "../../modules/lazerbar/OverlayCoordinatorLogic.js" as Logic

// Verify target validation and visual-owner classification without loading QML surfaces.
TestCase {
    name: "OverlayCoordinatorLogic"

    function test_targetClassification() {
        compare(Logic.normalizeTarget("wiki"), "wiki")
        compare(Logic.normalizeTarget("remote"), "")
        compare(Logic.ownerFor("wiki"), "wave")
        compare(Logic.ownerFor("settings"), "settings")
        compare(Logic.ownerFor("music"), "music")
        compare(Logic.ownerFor("remote"), "")
        verify(Logic.isSameOwner("wiki", "news"))
        verify(!Logic.isSameOwner("wiki", "settings"))
    }
}
