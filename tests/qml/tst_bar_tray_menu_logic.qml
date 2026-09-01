import QtQuick
import QtTest
import "../../modules/bar/BarTrayMenuLogic.js" as Logic

Item {
    width: 1; height: 1
    TestCase {
        name: "BarTrayMenuLogic"
        function test_entryListAcceptsArrayAndValues() {
            compare(Logic.entryList(null).length, 0)
            compare(Logic.entryList({ values: [{ text: "A" }] }).length, 1)
            compare(Logic.entryList([{ text: "B" }]).length, 1)
        }
        function test_separatorAndChildrenFlags() {
            verify(Logic.isSeparator({ isSeparator: true }))
            verify(!Logic.isEnabled({ enabled: false }))
            verify(Logic.hasChildren({ hasChildren: true }))
            verify(Logic.isChecked({ checkState: Qt.Checked }))
            verify(!Logic.isChecked({ checkState: Qt.Unchecked }))
        }
        function test_openCloseAndDismissRules() {
            verify(Logic.shouldOpenSubmenu({ hasChildren: true, enabled: true, isSeparator: false }))
            verify(!Logic.shouldOpenSubmenu({ hasChildren: true, enabled: false }))
            verify(Logic.shouldCloseSubmenuOnRow(1, false))
            verify(!Logic.shouldCloseSubmenuOnRow(1, true))
            verify(!Logic.shouldCloseSubmenuOnRow(2, false))
            verify(Logic.shouldDismissOnTrigger({ hasChildren: false, isSeparator: false }))
            verify(!Logic.shouldDismissOnTrigger({ checkState: Qt.Checked }))
            verify(!Logic.shouldDismissOnTrigger({ hasChildren: true }))
        }
        function test_emptyStateAndHandle() {
            verify(Logic.emptyStateVisible(null, []))
            verify(Logic.emptyStateVisible({}, []))
            verify(!Logic.emptyStateVisible({ id: 1 }, [{ text: "A" }]))
            compare(Logic.menuHandleFromPayload({ hasMenu: true, menu: "h" }), "h")
            compare(Logic.menuHandleFromPayload({ hasMenu: false, menu: "h" }), null)
            compare(Logic.menuHandleFromPayload({ menuHandle: "x" }), "x")
        }
        function test_heightHoldAndRelease() {
            compare(Logic.heldHeight(8, 120), 120)
            compare(Logic.heldHeight(80, 120), 80)
            verify(!Logic.releaseSubmenuData(0.4, "closing"))
            verify(!Logic.releaseSubmenuData(0, "closing"))
            verify(!Logic.releaseSubmenuData(0, "opening"))
            verify(Logic.releaseSubmenuData(0, "closed"))
        }
    }
}
