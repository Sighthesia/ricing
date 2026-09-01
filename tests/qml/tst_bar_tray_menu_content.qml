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
            var item = createTemporaryObject(menuComp, root, { menuHandle: null, entries: [], useStubEntries: true })
            verify(item.emptyStateVisible)
            compare(findByName(item, "trayEmptyState").visible, true)
        }
        function test_rowsRenderAndSeparatorNotClickable() {
            var sep = fakeEntry("", { isSeparator: true })
            var open = fakeEntry("Open")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [sep, open], useStubEntries: true })
            verify(!item.emptyStateVisible)
            compare(item.rowCount, 2)
        }
        function test_plainTriggerDismisses() {
            var open = fakeEntry("Open")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [open], useStubEntries: true })
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(open, 1)
            compare(open.triggeredCalls, 1)
            compare(dismissed, 1)
        }
        function test_throwingTriggerStillDismisses() {
            var entry = fakeEntry("Throws")
            entry.triggered = function() { throw new Error("test") }
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [entry], useStubEntries: true })
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(entry, 1)
            compare(dismissed, 1)
        }
        function test_checkboxDoesNotDismiss() {
            var mute = fakeEntry("Mute", { checkState: Qt.Checked })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [mute], useStubEntries: true })
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
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent], useStubEntries: true })
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
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent], useStubEntries: true })
            item.openSubmenu(parent, null)
            compare(findByName(item, "traySubmenuSurface").opacity, 1)
            compare(findByName(item, "trayMenuRowSurface").color, Lazer.LazerTheme.settingsCard)
            compare(Lazer.LazerTheme.settingsCardHover !== Lazer.LazerTheme.settingsCard, true)
        }
        function test_closeRetainsSubmenuDataDuringAnimation() {
            Lazer.MotionTokens.reducedMotionOverride = false
            var parent = fakeEntry("More", { hasChildren: true })
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent], useStubEntries: true })
            item.openSubmenu(parent, null)
            item.closeSubmenu()
            compare(item.submenuEntry, parent)
            tryCompare(item, "submenuEntry", null, Lazer.MotionTokens.slow + 100)
        }
        function test_levelTwoDoesNotCloseSubmenu() {
            var parent = fakeEntry("More", { hasChildren: true })
            var nested = fakeEntry("Nested")
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [parent], useStubEntries: true })
            item.openSubmenu(parent, null)
            item.handleRowHover(2, false)
            compare(item.submenuEntry, parent)
            item.handleRowHover(1, false)
            compare(item.submenuEntry, parent)
        }
        function test_submenuAnchorsToRootRow() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var first = fakeEntry("First")
            var second = fakeEntry("Second")
            var parent = fakeEntry("More", { hasChildren: true })
            var item = createTemporaryObject(menuComp, root, {
                menuHandle: {}, entries: [first, second, parent], useStubEntries: true
            })
            var rows = findAllByName(item, "trayMenuRow")
            item.openSubmenu(parent, rows[rows.length - 1])
            compare(item.submenuSurface.y, rows[rows.length - 1].y)
            verify(rows[rows.length - 1].y > 0)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_longMenuIsBoundedAndScrollable() {
            var many = []
            for (var i = 0; i < 40; i++)
                many.push(fakeEntry("Entry " + i))
            var item = createTemporaryObject(menuComp, root, {
                menuHandle: {}, entries: many, useStubEntries: true
            })
            var flick = findByName(item, "trayMenuFlick")
            verify(item.implicitHeight <= item.maxMenuHeight)
            verify(flick.contentHeight > flick.height)
            verify(flick.interactive)
        }
        function test_heldHeightKeepsPreviousWhenTiny() {
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [fakeEntry("A")], useStubEntries: true })
            item.noteColumnHeight(120)
            item.noteColumnHeight(8)
            compare(item.heldHeight, 120)
        }
        function test_faceOccludesSubmenu() {
            var item = createTemporaryObject(menuComp, root, { menuHandle: {}, entries: [fakeEntry("More", { hasChildren: true })], useStubEntries: true })
            verify(item.submenuSurface.z < item.menuFace.z)
            compare(item.submenuSurface.opacity, 1)
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

    function findAllByName(item, name, result) {
        var found = result || []
        if (!item) return found
        if (item.objectName === name)
            found.push(item)
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++)
                findAllByName(kids[i], name, found)
        }
        return found
    }
}
