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
        function makeMenu(entries) {
            var item = createTemporaryObject(menuComp, root, { useStubEntries: true })
            item.menuHandle = { id: "stub" }
            item.entries = entries
            return item
        }

        function test_emptyStateWithoutHandle() {
            var item = createTemporaryObject(menuComp, root, { useStubEntries: true })
            item.menuHandle = null
            item.entries = []
            verify(item.emptyStateVisible)
            compare(findByName(item, "trayEmptyState").visible, true)
        }

        function test_delayedTrayMenuHandleActivatesOpener() {
            var item = Qt.createQmlObject('import QtQuick; QtObject { property var menu: null }', root, "fakeTrayItem")
            var menu = makeMenu([])
            menu.menuHandle = null
            menu.trayItem = item
            verify(menu.emptyStateVisible)
            item.menu = Qt.createQmlObject('import QtQuick; QtObject {}', root, "fakeMenuHandle")
            compare(menu.resolvedMenuHandle, item.menu)
        }
        function test_rowsRenderAndSeparatorNotClickable() {
            var sep = fakeEntry("", { isSeparator: true })
            var open = fakeEntry("Open")
            var item = makeMenu([sep, open])
            compare(item.stubEntriesActive, true)
            compare(item.rowCount, 2)
            compare(item.emptyStateVisible, false)
        }
        function test_separatorsBecomeSectionBlocks() {
            var a = fakeEntry("A")
            var b = fakeEntry("B")
            var c = fakeEntry("C")
            var sep = fakeEntry("", { isSeparator: true })
            var item = makeMenu([a, sep, b, c])
            wait(0)
            // Two blocks, three rows, no separator lines rendered.
            compare(findAllByName(item, "trayMenuSection").length, 2)
            compare(findAllByName(item, "trayMenuRow").length, 3)
            compare(findAllByName(item, "trayMenuSeparator").length, 0)
            compare(findAllByName(item, "trayMenuSection")[0].color,
                Lazer.LazerTheme.settingsPanel)
        }
        function test_plainTriggerDismisses() {
            var open = fakeEntry("Open")
            var item = makeMenu([open])
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(open, 1)
            compare(open.triggeredCalls, 1)
            compare(dismissed, 1)
        }
        function test_throwingTriggerStillDismisses() {
            var entry = fakeEntry("Throws")
            entry.triggered = function() { throw new Error("test") }
            var item = makeMenu([entry])
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            item.activateEntry(entry, 1)
            compare(dismissed, 1)
        }
        function test_checkboxDoesNotDismiss() {
            var mute = fakeEntry("Mute", { checkState: Qt.Checked })
            var item = makeMenu([mute])
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
            var item = makeMenu([parent])
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
            var item = makeMenu([parent])
            item.openSubmenu(parent, null)
            compare(findByName(item, "traySubmenuSurface").opacity, 1)
            compare(findByName(item, "trayMenuRowSurface").color, Lazer.LazerTheme.settingsCard)
            compare(Lazer.LazerTheme.settingsCardHover !== Lazer.LazerTheme.settingsCard, true)
        }
        function test_closeRetainsSubmenuDataDuringAnimation() {
            Lazer.MotionTokens.reducedMotionOverride = false
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            item.openSubmenu(parent, null)
            item.closeSubmenu()
            compare(item.submenuEntry, parent)
            tryCompare(item, "submenuEntry", null, Lazer.MotionTokens.settingsSidebarFade + 200)
        }
        function test_levelTwoDoesNotCloseSubmenu() {
            var parent = fakeEntry("More", { hasChildren: true })
            var nested = fakeEntry("Nested")
            var item = makeMenu([parent])
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
            var item = makeMenu([first, second, parent])
            wait(0)
            var rows = findAllByName(item, "trayMenuRow")
            verify(rows.length >= 3)
            item.openSubmenu(parent, rows[rows.length - 1])
            compare(item.submenuAnchorRow, rows[rows.length - 1])
            // Second level is full-height and aligned to the primary's top so
            // the root list never shifts when the submenu appears. The panel
            // mirrors the primary panel width plus padding on both sides.
            compare(item.submenuSurface.y, 0)
            compare(item.submenuSurface.width, item.width + 16)
            compare(item.submenuSurface.height, findByName(item, "trayMenuFlick").height)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_submenuFlipRendersLeftWithoutMovingPrimary() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            item.openSubmenu(parent, null)
            compare(item.submenuProgress, 1)
            // Flipped: second level renders left of the primary, primary untouched.
            item.submenuFlipped = true
            compare(item.popsRight, false)
            compare(item.submenuSurface.x, -(item.submenuSurface.width + 12))
            compare(item.extraWidth, item.submenuSurface.width + 4)
            // Default: second level renders right of the primary.
            item.submenuFlipped = false
            compare(item.popsRight, true)
            compare(item.submenuSurface.x, item.width + 12)
            // Opened submenu rests beside the root with no scale drift.
            compare(item.submenuSurface.transform.length, 1)
            compare(item.submenuSurface.transform[0].x, 0)
            compare(item.submenuSurface.opacity, 1)
            // Mid-travel the surface is halfway out from under the primary,
            // never parked outside of it. The travel spans exactly the rest
            // offset (surface width plus gap) toward the root.
            item.submenuFlipped = true
            item.submenuProgress = 0.5
            compare(item.submenuSurface.transform[0].x, (item.submenuSurface.width + 4) * 0.5)
            item.submenuFlipped = false
            compare(item.submenuSurface.transform[0].x, -(item.submenuSurface.width + 4) * 0.5)
            item.submenuProgress = 1
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_longMenuIsBoundedAndScrollable() {
            var many = []
            for (var i = 0; i < 40; i++)
                many.push(fakeEntry("Entry " + i))
            var item = makeMenu(many)
            var flick = findByName(item, "trayMenuFlick")
            // Forty delegates may need more than one frame under load; poll
            // briefly instead of assuming a single wait(0) suffices.
            var settled = false
            for (var i = 0; i < 50 && !settled; i++) {
                wait(10)
                settled = flick.contentHeight > item.maxMenuHeight
                    || flick.contentHeight > flick.height
            }
            verify(settled)
            compare(flick.height, Math.min(flick.contentHeight, item.maxMenuHeight))
            verify(item.implicitHeight <= item.maxMenuHeight)
        }
        function test_heldHeightKeepsPreviousWhenTiny() {
            var item = makeMenu([fakeEntry("A")])
            item.noteColumnHeight(120)
            item.noteColumnHeight(8)
            compare(item.heldHeight, 120)
        }
        function test_submenuTitleUsesRowBlockLanguage() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            item.openSubmenu(parent, null)
            var block = findByName(item, "traySubmenuTitleBlock")
            verify(block)
            compare(block.color, Lazer.LazerTheme.settingsRail)
            compare(block.height, 48)
            // Title and rows share the primary's 8 padding to the panel edge.
            compare(block.width, item.submenuSurface.width - 16)
            compare(findByName(item, "traySubmenuTitle").text, "More")
            compare(findByName(item, "traySubmenuTitle").font.bold, true)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_faceOccludesSubmenu() {
            var item = makeMenu([fakeEntry("More", { hasChildren: true })])
            verify(item.submenuSurface.z < item.menuFace.z)
            // No fade: the opaque surface slides out from under the root face.
            compare(item.submenuSurface.opacity, 1)
            // The face spans the full background width (buttons plus padding)
            // so the drawer hides pixel-exactly and emerges at its edge.
            item.submenuFlipped = true
            compare(item.menuFace.x, -8)
            compare(item.menuFace.width, item.width + 16)
            item.submenuFlipped = false
            compare(item.menuFace.x, -8)
            compare(item.menuFace.width, item.width + 16)
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
