import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/lazerbar" as Lazer

Item {
    id: root
    width: 400; height: 800
    Component { id: menuComp; Bar.BarTrayMenuContent {} }

    function fakeEntry(text, extra) {
        var e = extra || ({})
        return {
            text: text,
            enabled: e.enabled !== false,
            isSeparator: !!e.isSeparator,
            hasChildren: !!e.hasChildren,
            checkState: e.checkState,
            triggeredCalls: 0,
            triggered: function() { this.triggeredCalls++ }
        }
    }

    TestCase {
        name: "BarTrayMenuContent"
        when: windowShown
        function test_emptyStateWithoutHandle() {
            var item = createTemporaryObject(menuComp, root, { menuHandle: null, entries: [] })
            verify(item.emptyStateVisible)
            compare(findByName(item, "trayEmptyState").visible, true)
        }
        function test_rowsRenderAndSeparatorNotClickable() {
            var sep = fakeEntry("", { isSeparator: true })
            var open = fakeEntry("Open")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [sep, open] })
            verify(!item.emptyStateVisible)
            compare(item.rowCount, 2)
        }
        function test_plainTriggerDismisses() {
            var open = fakeEntry("Open")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [open] })
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(open, 1)
            compare(open.triggeredCalls, 1)
            compare(dismissed, 1)
        }
        function test_checkboxDoesNotDismiss() {
            var mute = fakeEntry("Mute", { checkState: Qt.Checked })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [mute] })
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(mute, 1)
            compare(mute.triggeredCalls, 1)
            compare(dismissed, 0)
        }
        function test_openSubmenuKeepsDataUntilClosed() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var child = fakeEntry("Child")
            var parent = fakeEntry("More", { hasChildren: true })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent] })
            item.openSubmenu(parent, null)
            compare(item.submenuPhase, "open")
            compare(item.submenuEntry, parent)
            item.closeSubmenu()
            compare(item.submenuProgress, 0)
            compare(item.submenuEntry, null)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_submenuSurfaceIsOpaqueAndRowsUseSettingsCards() {
            var parent = fakeEntry("More", { hasChildren: true })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent] })
            item.openSubmenu(parent, null)
            compare(findByName(item, "traySubmenuSurface").opacity, 1)
            compare(findByName(item, "trayMenuRowSurface").color, Lazer.LazerTheme.settingsCard)
            compare(Lazer.LazerTheme.settingsCardHover !== Lazer.LazerTheme.settingsCard, true)
        }
        function test_closeRetainsSubmenuDataDuringAnimation() {
            Lazer.MotionTokens.reducedMotionOverride = false
            var parent = fakeEntry("More", { hasChildren: true })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent] })
            item.openSubmenu(parent, null)
            item.closeSubmenu()
            compare(item.submenuEntry, parent)
            tryCompare(item, "submenuEntry", null, Lazer.MotionTokens.slow + 100)
        }
        function test_levelTwoDoesNotCloseSubmenu() {
            var parent = fakeEntry("More", { hasChildren: true })
            var nested = fakeEntry("Nested")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent] })
            item.openSubmenu(parent, null)
            item.handleRowHover(2, false)
            compare(item.submenuEntry, parent)
            item.handleRowHover(1, false)
            verify(item.submenuPhase === "closing" || item.submenuProgress === 0 || item.submenuEntry === parent)
        }
    }

    function findByName(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var r = findByName(kids[i], name)
                if (r) return r
            }
        }
        return null
    }
}
