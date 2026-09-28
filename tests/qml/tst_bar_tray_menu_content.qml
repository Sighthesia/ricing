import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/lazerbar" as Lazer

Item {
    id: root
    width: 400; height: 800
    Component { id: menuComp; Bar.BarTrayMenuContent {} }
    // Plain containers for the nesting probes: the desktop puts the tray inside
    // a content layer whose width is fixed by childrenRect, which is narrower
    // than the submenu column that overflows it.
    Component {
        id: wideComp
        Item { width: 512; height: 421 }
    }
    Component {
        id: narrowComp
        Item { width: 260; height: 372 }
    }

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
        function hoverFresh(item, x, y) {
            // Two unconditional hops: the cursor cannot coincide with both,
            // so the final leg is always a real movement with real events.
            // (Reported containsMouse can lag the physical position.)
            mouseMove(item.parent, 350, 700)
            wait(20)
            mouseMove(item.parent, 10, 600)
            wait(20)
            mouseMove(item, x, y)
            wait(30)
        }
        // Root-level rows only; submenu delegates share the objectName.
        function primaryRowsOf(target) {
            var found = []
            var all = findAllByName(target, "trayMenuRow")
            for (var i = 0; i < all.length; i++) {
                if (all[i].level === 1)
                    found.push(all[i])
            }
            return found
        }
        // Poll an action until check passes: synthetic delivery flakes under
        // load, so retry the stimulus instead of asserting one shot.
        function pollAct(action, check, tries) {
            for (var i = 0; i < (tries || 12); i++) {
                action()
                wait(100)
                if (check())
                    return true
            }
            return check()
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
        function test_submenuOpenerKeepsEntryHandle() {
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            item.openSubmenu(parent, null)
            compare(item.submenuEntry, parent)
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
        function test_hoverCatcherLiveSwitchesParents() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var parentA = fakeEntry("A", { hasChildren: true })
            var parentB = fakeEntry("B", { hasChildren: true })
            var item = makeMenu([parentA, parentB])
            wait(0)
            // NOTE: mapped entries are Repeater copies, so compare by value.
            hoverFresh(item, 100, 16)
            // Real hover over row A (y 16) opens A.
            verify(pollAct(function() { mouseMove(item, 100, 16) },
                function() { return item.submenuEntry !== null && item.submenuEntry.text === "A" }))
            verify(item.highlightedRow !== null)
            // Real hover over row B (y 50) redirects to B, no stick.
            verify(pollAct(function() { mouseMove(item, 100, 50) },
                function() { return item.submenuEntry !== null && item.submenuEntry.text === "B" }))
            // Real hover in the gap (y 34) clears highlight and retracts.
            // (Single separating wait: back-to-back synthetic moves coalesce.)
            mouseMove(item, 100, 70)
            wait(50)
            verify(pollAct(function() { mouseMove(item, 100, 34) },
                function() { return item.submenuPhase === "closed" }))
            verify(item.highlightedRow === null)
            mouseMove(item, 350, 700)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_hoverCatcherLetsClicksThrough() {
            var plain = fakeEntry("Plain")
            var item = makeMenu([plain])
            wait(0)
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            // Real click through the overlay catcher still activates the
            // row. (Triggered-call counting on the stub is covered by the
            // direct activateEntry tests: Repeater copies plain objects, so
            // only the dismiss signal proves delivery here.)
            hoverFresh(item, 100, 16)
            // Synthetic press/release delivery flakes under load; retry the
            // stimulus instead of asserting one shot.
            verify(pollAct(function() { mouseClick(item, 100, 16) },
                function() { return dismissed === 1 }))
            compare(dismissed, 1)
        }
        function test_submenuCloseDoesNotRestartMidFlight() {
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            item.openSubmenu(parent, null)
            tryCompare(item, "submenuPhase", "open", 900)
            // Freeze the retraction, then close again: still stopped means
            // the second close did not restart it (restarts would stall the
            // retraction forever under a moving cursor).
            item.closeSubmenu()
            item.submenuAnimation.stop()
            item.closeSubmenu()
            wait(100)
            compare(item.submenuAnimation.running, false)
            compare(item.submenuPhase, "closing")
        }
        function test_submenuHighlightAppearsAndSurvivesRebuild() {
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                var parent = fakeEntry("More", { hasChildren: true })
                // Three primary rows so the surface fits title plus content.
                // Poll for layout like the long-menu test: heights need polish.
                var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
                // Park the cursor outside every catcher first: a stale
                // position from an earlier pointer test can sit inside the
                // future submenu rect and fire a ghost enter as the surface
                // appears, racing the memory resolve below.
                mouseMove(item, 350, 700)
                wait(20)
                mouseMove(item, 10, 600)
                wait(20)
                var laidOut = false
                for (var i = 0; i < 100 && !laidOut; i++) {
                    wait(10)
                    laidOut = findByName(item, "trayMenuFlick").height > 0
                }
                verify(laidOut)
                // Open with no content yet (cold fetch), stage parked-cursor
                // memory as a real arrival would leave it, then content arrives
                // under the parked cursor and must highlight via memory resolve.
                // Sample the point from live geometry: the anchor pin lands
                // at open time, so pre-batch coordinates stay valid.
                item.openSubmenu(parent, null)
                var stagePoint = null
                for (var s = 0; s < 100 && stagePoint === null; s++) {
                    wait(10)
                    var sfl = findByName(item, "traySubmenuFlick")
                    if (sfl && sfl.y === 56 && sfl.height > 0)
                        stagePoint = sfl.mapToItem(item, 40, 16)
                }
                verify(stagePoint !== null)
                item.lastCursorX = stagePoint.x
                item.lastCursorY = stagePoint.y
                item.submenuEntries = [fakeEntry("Child")]
                for (var j = 0; j < 20; j++) {
                    item.resolveSubHoverFromMemory()
                    wait(10)
                    var probe = findByName(findByName(item, "traySubmenuSurface"), "trayMenuRowSurface")
                    if (probe && probe.color === Lazer.LazerTheme.settingsCardHover)
                        break
                }
                var surf = findByName(findByName(item, "traySubmenuSurface"), "trayMenuRowSurface")
                verify(surf !== null)
                compare(surf.color, Lazer.LazerTheme.settingsCardHover)
                // Cold-style batch with identical content rebuilds delegates
                // under the parked cursor; highlight must survive.
                item.submenuEntries = [fakeEntry("Child")]
                for (var k = 0; k < 20; k++) {
                    item.resolveSubHoverFromMemory()
                    wait(10)
                    if (surf && surf.color === Lazer.LazerTheme.settingsCardHover)
                        break
                }
                var surf2 = findByName(findByName(item, "traySubmenuSurface"), "trayMenuRowSurface")
                verify(surf2 !== null)
                compare(surf2.color, Lazer.LazerTheme.settingsCardHover)
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }
        function test_submenuLeafClickRetractsBeforeDismiss() {
            // Animated: the click frame must start the retract (phase
            // closing, data kept) while still emitting the dismiss.
            var child = fakeEntry("Child")
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            item.openSubmenu(parent, null)
            tryCompare(item, "submenuPhase", "open", 900)
            item.submenuEntries = [child]
            wait(0)
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            var live = item.submenuSections[0][0]
            item.activateEntry(live, 2)
            compare(live.triggeredCalls, 1)
            compare(dismissed, 1)
            // Retract starts on the click frame; data releases at progress 0.
            compare(item.submenuPhase, "closing")
            compare(item.submenuEntry !== null, true)
            tryCompare(item, "submenuEntry", null, Lazer.MotionTokens.settingsSidebarFade + 300)
        }
        function test_columnCatcherBridgesColdFetch() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
            wait(0)
            item.openSubmenu(parent, null)
            // Cold fetch: no rows yet, so the panel stays hidden — but the
            // column band beside the primary is still live input.
            var column = findByName(item, "traySubmenuColumnCatcher")
            verify(column !== null)
            compare(column.visible, true)
            compare(findByName(item, "traySubmenuSurface").visible, false)
            // The band starts flush with the primary and spans the panel width.
            compare(column.x, findByName(item, "trayMenuFlick").width)
            compare(column.width, findByName(item, "traySubmenuSurface").width + 8)
            // Traversal parks the cursor; the late batch highlights from it.
            // Poll like the long-menu test: delegates position over frames.
            // Sample from live geometry: the anchor pin lands at open time.
            var cpoint = null
            for (var c = 0; c < 100 && cpoint === null; c++) {
                wait(10)
                var cfl = findByName(item, "traySubmenuFlick")
                if (cfl && cfl.y === 56 && cfl.height > 0)
                    cpoint = cfl.mapToItem(item, 40, 16)
            }
            verify(cpoint !== null)
            item.lastCursorX = cpoint.x
            item.lastCursorY = cpoint.y
            item.submenuEntries = [fakeEntry("Child")]
            var hl = null
            for (var i = 0; i < 100 && hl === null; i++) {
                wait(10)
                hl = item.highlightedSubmenuRow
            }
            verify(hl !== null)
            // Rows landed: the row under the remembered point is highlighted
            // and taps are live, with no handoff step in between.
            compare(findByName(item, "traySubmenuSurface").visible, true)
            var surf = findByName(findByName(item, "traySubmenuSurface"), "trayMenuRowSurface")
            verify(surf !== null)
            compare(surf.color, Lazer.LazerTheme.settingsCardHover)
            compare(item.submenuInteractable, true)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_transitToSubmenuBouncesBackFromClosing() {
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            // Side-aware column geometry: flush with the primary on the right,
            // mirrored to the panel's outer edge when flipped left.
            var column = findByName(item, "traySubmenuColumnCatcher")
            compare(column.x, findByName(item, "trayMenuFlick").width)
            item.submenuFlipped = true
            compare(column.x, -(findByName(item, "traySubmenuSurface").width + 8))
            item.submenuFlipped = false
            // Fully closed with no entry: deliberate no-op.
            item.transitToSubmenu()
            compare(item.submenuPhase, "closed")
            // Mid-retract arrival bounces back at once (phase assignments
            // are synchronous, so no waits needed for the direction).
            item.openSubmenu(parent, null)
            tryCompare(item, "submenuPhase", "open", 900)
            item.closeSubmenu()
            compare(item.submenuPhase, "closing")
            item.transitToSubmenu()
            compare(item.submenuPhase, "opening")
            compare(item.submenuEntry, parent)
        }
        function test_submenuEdgeToleranceIgnoresJitter() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            wait(0)
            // 2px inside the row edge: boundary jitter must not summon.
            item.actOnMappedRow(item.entryAtContentY(2))
            compare(item.submenuPhase, "closed")
            compare(item.submenuEntry, null)
            // 2px above the bottom edge: same.
            item.actOnMappedRow(item.entryAtContentY(30))
            compare(item.submenuPhase, "closed")
            // 16px deep: deliberate entry opens at once.
            item.actOnMappedRow(item.entryAtContentY(16))
            compare(item.submenuPhase, "open")
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_hoverCatcherMapsEveryPixelToARow() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var parent = fakeEntry("More", { hasChildren: true })
            var plain = fakeEntry("Plain")
            var item = makeMenu([parent, plain])
            wait(0)
            // Rows are 32 high with 4 gaps; gaps map to nothing: no summon,
            // no highlight, parking in one counts as off the buttons.
            compare(item.entryAtContentY(10).entry, parent)
            verify(item.entryAtContentY(34).entry === null)
            verify(item.entryAtContentY(34).row === null)
            compare(item.entryAtContentY(40).entry, plain)
            // Acting follows the mapping: parent opens, gap retracts an
            // open submenu but never aborts one still opening (travel).
            item.actOnMappedRow(item.entryAtContentY(10))
            compare(item.submenuPhase, "open")
            item.actOnMappedRow(item.entryAtContentY(34))
            compare(item.submenuPhase, "closed")
            item.openSubmenu(parent, null)
            item.submenuPhase = "opening"
            item.actOnMappedRow(item.entryAtContentY(34))
            compare(item.submenuPhase, "opening")
            Lazer.MotionTokens.reducedMotionOverride = false
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
            // Anchor pin: title top will meet this row's bottom edge.
            var anchorBottom = rows[rows.length - 1].mapToItem(item, 0, 32).y
            compare(item.submenuAnchorBottomY, anchorBottom)
            // Anchor sits at the primary bottom here, so the panel shifts up
            // to stay inside instead of overflowing below. Width still
            // mirrors the primary panel plus padding on both sides.
            var flickH = findByName(item, "trayMenuFlick").height
            compare(item.submenuSurface.y, Math.max(0, flickH - 96))
            compare(item.submenuSurface.width, item.width + 8)
            compare(item.submenuSurface.height, flickH)
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
            compare(item.submenuSurface.x, -(item.submenuSurface.width + 8))
            compare(item.extraWidth, item.submenuSurface.width)
            // Default: second level renders right of the primary.
            item.submenuFlipped = false
            compare(item.popsRight, true)
            compare(item.submenuSurface.x, item.width + 8)
            // Opened submenu rests beside the root with no scale drift.
            compare(item.submenuSurface.transform.length, 1)
            compare(item.submenuSurface.transform[0].x, 0)
            compare(item.submenuSurface.opacity, 1)
            // Mid-travel the surface is halfway out from under the primary,
            // never parked outside of it. The travel spans exactly the rest
            // offset (surface width plus gap) toward the root.
            item.submenuFlipped = true
            item.submenuProgress = 0.5
            compare(item.submenuSurface.transform[0].x, (item.submenuSurface.width + 8) * 0.5)
            // Padding lives only on the outer edge; the meeting edge is flush.
            compare(findByName(item, "traySubmenuFlick").anchors.leftMargin, 8)
            compare(findByName(item, "traySubmenuFlick").anchors.rightMargin, 0)
            item.submenuFlipped = false
            compare(item.submenuSurface.transform[0].x, -(item.submenuSurface.width + 8) * 0.5)
            compare(findByName(item, "traySubmenuFlick").anchors.leftMargin, 0)
            compare(findByName(item, "traySubmenuFlick").anchors.rightMargin, 8)
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
            for (var i = 0; i < 100 && !settled; i++) {
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
            // Title layer is full-bleed like the identity header; only the
            // rows keep the 8 padding to the panel edge.
            compare(block.width, item.submenuSurface.width)
            compare(findByName(item, "traySubmenuTitle").text, "More")
            compare(findByName(item, "traySubmenuTitle").font.bold, true)
            // Title pinned to the panel top; rows start below it with the
            // outer-edge padding rhythm.
            compare(block.y, 0)
            compare(findByName(item, "traySubmenuFlick").anchors.topMargin, 56)
            compare(findByName(item, "traySubmenuFlick").anchors.bottomMargin, 8)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_submenuRowsInteractableOnlyWhenOpen() {
            Lazer.MotionTokens.reducedMotionOverride = true
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([parent])
            compare(item.submenuInteractable, false)
            item.openSubmenu(parent, null)
            compare(item.submenuInteractable, true)
            item.closeSubmenu()
            compare(item.submenuInteractable, false)
            Lazer.MotionTokens.reducedMotionOverride = false
        }
        function test_longSubmenuAnchorsAndClampsToPrimary() {
            // The panel hangs from its anchor row (title top flush with the
            // anchor bottom edge) and never leaves the primary vertical
            // range; longer submenus scroll inside instead of growing the
            // popup. Eight primary rows give a mid-list anchor real room.
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                // Twenty rows overflow any clamped viewport, so the excess
                // must scroll inside it.
                var submenu = []
                for (var i = 0; i < 20; i++)
                    submenu.push(fakeEntry("Child " + i))
                var primaries = [fakeEntry("Top"), fakeEntry("More", { hasChildren: true })]
                for (var p = 0; p < 6; p++)
                    primaries.push(fakeEntry(" filler " + p))
                var parent = primaries[1]
                var item = makeMenu(primaries)
                // Anchor math reads live primary geometry: wait for the
                // anchor row AND a stable primary height, or later rows
                // landing mid-assert will move everything under us.
                var anchor = null
                var primaryHeight = 0
                var stableP = 0
                for (var j = 0; j < 400 && (anchor === null || stableP < 5); j++) {
                    wait(10)
                    var prows = primaryRowsOf(item)
                    if (prows.length >= 8 && prows[1].y > 0)
                        anchor = prows[1]
                    var curP = findByName(item, "trayMenuFlick").height
                    if (anchor !== null && curP > 0 && curP === primaryHeight)
                        stableP++
                    else {
                        stableP = 0
                        primaryHeight = curP
                    }
                }
                verify(anchor !== null)
                verify(primaryHeight > 0)
                var anchorBottom = anchor.mapToItem(item, 0, 32).y
                item.submenuEntries = submenu
                item.openSubmenu(parent, anchor)
                // Pin wiring: title top meets the anchor bottom edge.
                compare(item.submenuAnchorBottomY, anchorBottom)
                compare(item.submenuSurface.y, anchorBottom)
                // Bottom-clamped to the primary flick: rows scroll inside.
                var settled = false
                for (var k = 0; k < 200 && !settled; k++) {
                    wait(10)
                    var probe = findByName(item, "traySubmenuFlick")
                    settled = probe && probe.contentHeight > probe.height && probe.height > 0
                }
                verify(settled)
                compare(item.submenuSurface.y + item.submenuSurface.height, primaryHeight)
                var flick = findByName(item, "traySubmenuFlick")
                verify(flick.contentHeight > flick.height)
                // Title stays pinned to the panel top.
                compare(findByName(item, "traySubmenuTitleBlock").y, 0)
                // The submenu adds no height beyond the primary list.
                compare(item.implicitHeight, Math.max(item.heldHeight, primaryHeight))
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
            // Animated: the clamped panel slides out at its final geometry.
            var item2 = makeMenu(primaries)
            var anchor2 = null
            var primary2 = 0
            var stableP2 = 0
            for (var m = 0; m < 400 && (anchor2 === null || stableP2 < 5); m++) {
                wait(10)
                var prows2 = primaryRowsOf(item2)
                if (prows2.length >= 8 && prows2[1].y > 0)
                    anchor2 = prows2[1]
                var curP2 = findByName(item2, "trayMenuFlick").height
                if (anchor2 !== null && curP2 > 0 && curP2 === primary2)
                    stableP2++
                else {
                    stableP2 = 0
                    primary2 = curP2
                }
            }
            verify(anchor2 !== null)
            verify(primary2 > 0)
            var anchorBottom2 = anchor2.mapToItem(item2, 0, 32).y
            item2.submenuEntries = submenu
            item2.openSubmenu(parent, anchor2)
            compare(item2.submenuPhase, "opening")
            compare(item2.submenuSurface.y, anchorBottom2)
            tryCompare(item2, "submenuPhase", "open", 1500)
            // Submenu layout trails the reveal: wait until rows overflow
            // the clamped viewport before asserting final geometry.
            var settled2 = false
            for (var s = 0; s < 200 && !settled2; s++) {
                wait(10)
                var probe2 = findByName(item2, "traySubmenuFlick")
                settled2 = probe2 && probe2.contentHeight > probe2.height && probe2.height > 0
            }
            verify(settled2)
            compare(item2.submenuSurface.y + item2.submenuSurface.height, primary2)
        }
        function test_realSubmenuPointerHoverAndClick() {
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                var parent = fakeEntry("More", { hasChildren: true })
                var child = fakeEntry("Child")
                var item = makeMenu([parent])
                item.openSubmenu(parent, null)
                item.submenuEntries = [child]
                var surface = null
                for (var i = 0; i < 200 && !(surface && surface.visible); i++) {
                    wait(10)
                    surface = findByName(item, "traySubmenuSurface")
                }
                verify(surface && surface.visible)
                var dismissed = 0
                item.dismissRequested.connect(function() { dismissed++ })
                var flick = findByName(item, "traySubmenuFlick")
                var point = flick.mapToItem(item, 40, 16)
                // Two-hop parking first: a jump straight from a stale cursor
                // position can arrive with no events (containsMouse lags the
                // physical position), so wake the chain like hoverFresh does.
                hoverFresh(item, point.x, point.y)
                // Synthetic hover/click delivery flakes under load; retry the
                // stimulus like the other pointer tests instead of one shot.
                verify(pollAct(function() { mouseMove(item, point.x, point.y) },
                    function() { return item.highlightedSubmenuRow !== null }))
                verify(pollAct(function() { mouseClick(item, point.x, point.y) },
                    function() { return dismissed === 1 }))
                compare(dismissed, 1)
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }
        function test_submenuHoverSurvivesMemoryResolve() {
            // The catcher fills the flickable: remembered coords must carry
            // the flick offset, or the next async settle (open-finish, batch)
            // recomputes a negative fy and wipes the live highlight.
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                // Park neutral BEFORE creating the menu: a stale cursor from
                // an earlier pointer test can sit inside the future submenu
                // rect and fire a ghost enter as the surface appears, latching
                // live coords into the fresh catchers.
                mouseMove(root, 350, 700)
                wait(20)
                mouseMove(root, 10, 600)
                wait(20)
                var parent = fakeEntry("More", { hasChildren: true })
                var item = makeMenu([parent])
                item.openSubmenu(parent, null)
                item.submenuEntries = [fakeEntry("Child")]
                var landed = false
                for (var i = 0; i < 200 && !landed; i++) {
                    wait(10)
                    landed = findAllByName(item, "trayMenuRow").length >= 2
                }
                verify(landed, "submenu delegates never landed")
                // Delegate existence precedes anchor layout by frames under
                // load: resolve needs the laid-out viewport, not just rows.
                var laid = false
                for (var w = 0; w < 200 && !laid; w++) {
                    wait(10)
                    var fl = findByName(item, "traySubmenuFlick")
                    laid = fl && fl.height >= 32
                }
                verify(laid, "submenu viewport never laid out")
                // Real hover on the first submenu row: the catcher fills the
                // panel, so this also proves the mapping through the title
                // strip lands on the row band rather than the title itself.
                var subFlick = findByName(item, "traySubmenuFlick")
                var rowPoint = subFlick.mapToItem(item, 40, 16)
                verify(pollAct(function() { hoverFresh(item, rowPoint.x, rowPoint.y) },
                    function() { return item.highlightedSubmenuRow !== null }),
                    "direct hover did not highlight")
                // The title band maps to no row but keeps the memory live.
                var titlePoint = findByName(item, "traySubmenuSurface").mapToItem(item, 40, 10)
                verify(pollAct(function() { mouseMove(item, titlePoint.x, titlePoint.y) },
                    function() { return item.highlightedSubmenuRow === null
                        && item.lastCursorX >= 0 }),
                    "title band forgot the pointer")
                // Back onto the first row, then simulate the async settle:
                // the highlight must survive it.
                verify(pollAct(function() { mouseMove(item, rowPoint.x, rowPoint.y) },
                    function() { return item.highlightedSubmenuRow !== null }))
                item.resolveSubHoverFromMemory()
                wait(30)
                verify(item.highlightedSubmenuRow !== null, "memory resolve wiped the highlight")
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }
        function test_columnBandCatchesFastCrossingIntoRows() {
            // The panel hangs from its trigger row's bottom edge, so travelling
            // right along the row crosses band that the panel does not paint.
            // Input has to belong to the whole band, not to the painted panel:
            // a single fast motion that skipped the old 8px transit strip used
            // to leave the arrival unregistered, so nothing highlighted and
            // nothing was tappable when the pointer dropped into the rows.
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                mouseMove(root, 380, 760); wait(20)
                mouseMove(root, 8, 700); wait(20)
                var parent = fakeEntry("More", { hasChildren: true })
                var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
                var row = null
                for (var i = 0; i < 200 && row === null; i++) {
                    wait(10)
                    var rows = primaryRowsOf(item)
                    if (rows.length >= 3 && rows[1].height > 0)
                        row = rows[1]
                }
                verify(row !== null, "primary rows never laid out")
                var rowPoint = row.mapToItem(item, 40, 16)
                hoverFresh(item, rowPoint.x, rowPoint.y)
                item.submenuEntries = [fakeEntry("Child")]
                var open = false
                for (var j = 0; j < 300 && !open; j++) {
                    wait(10)
                    var s = findByName(item, "traySubmenuSurface")
                    var f = findByName(item, "traySubmenuFlick")
                    open = s && s.visible && f && f.height >= 32
                }
                verify(open, "submenu never revealed")
                var column = findByName(item, "traySubmenuColumnCatcher")
                // The band starts flush with the primary, so the whole travel
                // line beside the row belongs to the second level.
                compare(column.x, findByName(item, "trayMenuFlick").width)
                // One jump past the old strip, along the trigger row's own y.
                var lineY = rowPoint.y
                var jumped = column.mapToItem(item, 60, lineY)
                verify(pollAct(function() { mouseMove(item, jumped.x, jumped.y) },
                    function() { return item.lastCursorX >= 0 }),
                    "the travel line beside the trigger row is not live input")
                // Drop into the first row: highlight and tap must both work.
                var flick = findByName(item, "traySubmenuFlick")
                var target = flick.mapToItem(item, 40, 16)
                verify(pollAct(function() { mouseMove(item, target.x, target.y) },
                    function() { return item.highlightedSubmenuRow !== null }),
                    "submenu rows never took the hover after a fast crossing")
                var dismissed = 0
                item.dismissRequested.connect(function() { dismissed++ })
                verify(pollAct(function() { mouseClick(item, target.x, target.y) },
                    function() { return dismissed === 1 }),
                    "submenu row click never landed after a fast crossing")
                // The click must not bounce the retracting submenu back open.
                wait(80)
                compare(item.submenuPhase !== "open", true)
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }
        function test_submenuTakesHoverOnArrivalFromPrimary() {
            // Realistic arrival path: hover the trigger row, travel right
            // along that row's own y (where the panel is not painted yet, so
            // only the transit strip is under the cursor), then drop into the
            // rows viewport. The rows must take the hover and stay clickable;
            // this is the path a real pointer takes and the one the direct
            // mapToItem jumps in the other pointer tests skip.
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                // Park outside the future panel rect before anything exists.
                mouseMove(root, 380, 760)
                wait(20)
                mouseMove(root, 8, 700)
                wait(20)
                var parent = fakeEntry("More", { hasChildren: true })
                var child = fakeEntry("Child")
                var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
                var row = null
                for (var i = 0; i < 200 && row === null; i++) {
                    wait(10)
                    var rows = primaryRowsOf(item)
                    if (rows.length >= 3 && rows[1].height > 0)
                        row = rows[1]
                }
                verify(row !== null, "primary rows never laid out")
                var rowPoint = row.mapToItem(item, 40, 16)
                // Hovering the trigger row summons the second level.
                hoverFresh(item, rowPoint.x, rowPoint.y)
                item.submenuEntries = [child]
                var open = false
                for (var j = 0; j < 300 && !open; j++) {
                    wait(10)
                    var s = findByName(item, "traySubmenuSurface")
                    var f = findByName(item, "traySubmenuFlick")
                    open = s && s.visible && f && f.height >= 32
                }
                verify(open, "submenu never revealed")
                compare(item.submenuPhase, "open")
                var surface = findByName(item, "traySubmenuSurface")
                var flick = findByName(item, "traySubmenuFlick")
                // Travel right along the trigger row: crosses the transit
                // strip, then crosses unpainted space above the panel. The
                // pointer memory must survive that crossing, or the second
                // level loses the only channel that can re-arm its highlight.
                var stripPoint = surface.mapToItem(item, 4, rowPoint.y)
                mouseMove(item, stripPoint.x, stripPoint.y)
                wait(30)
                mouseMove(item, stripPoint.x + 40, stripPoint.y)
                wait(30)
                verify(item.lastCursorX >= 0, "traversing the transit strip forgot the cursor")
                // Drop into the first submenu row.
                var target = flick.mapToItem(item, 40, 16)
                verify(pollAct(function() { mouseMove(item, target.x, target.y) },
                    function() { return item.highlightedSubmenuRow !== null }),
                    "submenu rows never took the hover on arrival")
                // Delegate modelData is a pragma-library copy, so a leaf click
                // is observed through the dismiss it requests, not triggeredCalls.
                var dismissed = 0
                item.dismissRequested.connect(function() { dismissed++ })
                verify(pollAct(function() { mouseClick(item, target.x, target.y) },
                    function() { return dismissed === 1 }),
                    "submenu row click never landed after arrival")
                compare(dismissed, 1)
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }
        function test_coldFetchHandoffKeepsTheArrival() {
            // Cold first-open path: the panel is still hidden when the pointer
            // arrives, so the pending bridge owns the area. When the late batch
            // lands the real surface takes that area over — the arrival must
            // survive the handoff and highlight under a pointer that never
            // moves again.
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                mouseMove(root, 380, 760); wait(20)
                mouseMove(root, 8, 700); wait(20)
                var parent = fakeEntry("More", { hasChildren: true })
                var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
                var row = null
                for (var i = 0; i < 200 && row === null; i++) {
                    wait(10)
                    var rows = primaryRowsOf(item)
                    if (rows.length >= 3 && rows[1].height > 0)
                        row = rows[1]
                }
                verify(row !== null, "primary rows never laid out")
                var rowPoint = row.mapToItem(item, 40, 16)
                hoverFresh(item, rowPoint.x, rowPoint.y)
                // Summoned with no content yet: the panel stays hidden while the
                // column band beside the primary is already live input.
                var summoned = false
                for (var j = 0; j < 200 && !summoned; j++) {
                    wait(10)
                    summoned = findByName(item, "traySubmenuSurface")
                        && !findByName(item, "traySubmenuSurface").visible
                        && findByName(item, "traySubmenuColumnCatcher").visible
                }
                verify(summoned, "cold panel never exposed its column band")
                // Arrive where the rows will be, before they exist.
                var surface = findByName(item, "traySubmenuSurface")
                var target = surface.mapToItem(item, 40, 48 + 8 + 16)
                verify(pollAct(function() { mouseMove(item, target.x, target.y) },
                    function() { return item.lastCursorX >= 0 }),
                    "bridge never took the arrival")
                // The late batch lands under the stationary pointer.
                item.submenuEntries = [fakeEntry("Child")]
                verify(pollAct(function() { item.resolveSubHoverFromMemory(); wait(20) },
                    function() { return item.highlightedSubmenuRow !== null }),
                    "handoff dropped the arrival: no highlight under a parked pointer")
                verify(item.lastCursorX >= 0, "handoff forgot the pointer")
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }
        function test_parkedPointerLightsUpOnFirstExpandWithoutPoking() {
            // The user's actual first-expand gesture: hover the trigger row, let
            // the panel fly in while the pointer stays put, then read it. Nothing
            // calls the resolver from here — the settle path has to do it on its
            // own, because a pointer parked over a panel that is still assembling
            // never produces another hover event.
            // Motion stays ON (500ms flight): a reduced-motion run would skip the
            // settle path that owns this behaviour.
            mouseMove(root, 380, 760); wait(20)
            mouseMove(root, 8, 700); wait(20)
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
            var row = null
            for (var i = 0; i < 200 && row === null; i++) {
                wait(10)
                var rows = primaryRowsOf(item)
                if (rows.length >= 3 && rows[1].height > 0)
                    row = rows[1]
            }
            verify(row !== null, "primary rows never laid out")
            var rowPoint = row.mapToItem(item, 40, 16)
            hoverFresh(item, rowPoint.x, rowPoint.y)
            // Park beside the primary, where the first submenu row will come to
            // rest. Use the surface's LAYOUT position, not mapToItem: the panel
            // slides in from the right, so mid-flight its mapped position is
            // still over the primary column and parking there is a different
            // (and correctly unhighlighted) situation.
            var surface = findByName(item, "traySubmenuSurface")
            verify(surface !== null, "no submenu surface")
            var target = { x: surface.x + 40, y: surface.y + 48 + 8 + 16 }
            verify(target.x >= findByName(item, "traySubmenuColumnCatcher").x,
                "the resting row position is not inside the submenu column")
            verify(pollAct(function() { mouseMove(item, target.x, target.y) },
                function() { return item.lastCursorX === target.x }),
                "the resting row position is not live input")
            var memoryX = item.lastCursorX
            var memoryY = item.lastCursorY
            // The cold batch lands; then the panel flies in and settles. From
            // here the pointer never moves again.
            item.submenuEntries = [fakeEntry("Child")]
            var settled = false
            for (var j = 0; j < 400 && !settled; j++) {
                wait(10)
                settled = item.submenuPhase === "open" && item.submenuInteractable
                    && item.highlightedSubmenuRow !== null
            }
            verify(item.submenuPhase === "open", "panel never settled on first expand")
            verify(item.submenuInteractable, "rows never became tappable after settle")
            verify(item.lastCursorX === memoryX && item.lastCursorY === memoryY,
                "the parked pointer was forgotten while the panel assembled")
            verify(item.highlightedSubmenuRow !== null,
                "parked pointer got no highlight when the panel settled")
            // And it is actually the row under the cursor, not some other row.
            var flick = findByName(item, "traySubmenuFlick")
            var live = flick.mapToItem(item, 40, 16)
            verify(Math.abs(live.x - target.x) < 2 && Math.abs(live.y - target.y) < 2,
                "the panel settled somewhere other than where the pointer parked")
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            verify(pollAct(function() { mouseClick(item, target.x, target.y) },
                function() { return dismissed === 1 }),
                "clicking the highlighted first-expand row did nothing")
        }
        function test_narrowAncestorStillDeliversHoverToTheOverflowingColumn() {
            // The desktop's real nesting, reproduced: the tray content sits in a
            // content layer that stays 260 wide (childrenRect of a 244-wide menu)
            // while the container around it is 512 wide, so the submenu column
            // band lives entirely OUTSIDE its own layer's declared width. The
            // panel still paints there, which is why this looked like a live
            // surface — the question is whether input reaches it.
            mouseMove(root, 380, 760); wait(20)
            mouseMove(root, 8, 700); wait(20)
            var parent = fakeEntry("More", { hasChildren: true })
            var outer = createTemporaryObject(wideComp, root, null)
            var slot = createTemporaryObject(narrowComp, outer, null)
            var item = createTemporaryObject(menuComp, slot, { useStubEntries: true })
            item.menuHandle = { id: "stub" }
            item.entries = [fakeEntry("Top"), parent, fakeEntry("Bottom")]
            wait(0)
            // The band must genuinely sit outside the narrow slot.
            var band = findByName(item, "traySubmenuColumnCatcher")
            verify(band !== null, "no column band")
            compare(band.x, 244)
            verify(band.x + band.width > slot.width,
                "probe is not testing an overflowing band")
            item.submenuEntries = [fakeEntry("Child")]
            item.openSubmenu(parent, null)
            var ready = false
            for (var i = 0; i < 300 && !ready; i++) {
                wait(10)
                var s = findByName(item, "traySubmenuSurface")
                var f = findByName(item, "traySubmenuFlick")
                // Settled, not merely revealed: the panel's slide is a transform,
                // so mapToItem mid-flight reports a position still over the
                // primary and the probe would silently test the wrong pixel.
                ready = s && s.visible && f && f.height > 0 && item.submenuPhase === "open"
            }
            verify(ready, "submenu never revealed inside the narrow slot")
            var flick = findByName(item, "traySubmenuFlick")
            var target = flick.mapToItem(slot, 40, 16)
            verify(target.x > slot.width,
                "probe row is not actually outside the narrow slot")
            verify(pollAct(function() { mouseMove(slot, target.x, target.y) },
                function() { return item.highlightedSubmenuRow !== null }),
                "a narrow ancestor blocked hover on the overflowing column")
        }
        function test_lateBatchAfterFlightStillOpensAndTakesHover() {
            // Coldest first-open shape: the DBus fetch outlasts the flight, so
            // the panel settles on an EMPTY body and the rows land afterwards.
            // Nothing re-runs the animation then, so "open" (which is what makes
            // rows tappable) has to already be true when the batch arrives.
            mouseMove(root, 380, 760); wait(20)
            mouseMove(root, 8, 700); wait(20)
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
            var row = null
            for (var i = 0; i < 200 && row === null; i++) {
                wait(10)
                var rows = primaryRowsOf(item)
                if (rows.length >= 3 && rows[1].height > 0)
                    row = rows[1]
            }
            verify(row !== null, "primary rows never laid out")
            var rowPoint = row.mapToItem(item, 40, 16)
            hoverFresh(item, rowPoint.x, rowPoint.y)
            var flew = false
            for (var j = 0; j < 400 && !flew; j++) {
                wait(10)
                flew = item.submenuPhase === "open"
            }
            verify(flew, "panel never finished its flight with no content")
            verify(item.hasSubmenuContent === false, "stub should report no content yet")
            // Park where the rows will be, then let the batch land post-settle.
            var surface = findByName(item, "traySubmenuSurface")
            var target = { x: surface.x + 40, y: surface.y + 48 + 8 + 16 }
            verify(pollAct(function() { mouseMove(item, target.x, target.y) },
                function() { return item.lastCursorX === target.x }),
                "the resting row position is not live input")
            item.submenuEntries = [fakeEntry("Child")]
            var ready = false
            for (var k = 0; k < 300 && !ready; k++) {
                wait(10)
                ready = item.submenuInteractable && item.highlightedSubmenuRow !== null
            }
            verify(item.submenuPhase === "open",
                "a late batch knocked the panel out of the open phase")
            verify(item.submenuInteractable,
                "rows stayed untappable when the batch landed after the flight")
            verify(item.highlightedSubmenuRow !== null,
                "a late batch left the parked pointer with no highlight")
            var dismissed = 0
            item.dismissRequested.connect(function() { dismissed++ })
            verify(pollAct(function() { mouseClick(item, target.x, target.y) },
                function() { return dismissed === 1 }),
                "a row delivered after the flight could not be clicked")
        }
        function test_submenuColumnNameResolvesToRowsColumn() {
            // `submenuColumn` is declared twice: exported as a property alias
            // of the input band, and used as the id of the rows Column. Inside
            // this file the mapper says the bare name, so whichever wins decides
            // whether the mapping can see sections at all. Assert it is the
            // Column, by object identity against the Column's own inventory.
            var parent = fakeEntry("More", { hasChildren: true })
            var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
            item.submenuEntries = [fakeEntry("Child")]
            item.openSubmenu(parent, null)
            for (var i = 0; i < 300; i++) {
                wait(10)
                var f = findByName(item, "traySubmenuFlick")
                if (f && f.height > 0)
                    break
            }
            var flick = findByName(item, "traySubmenuFlick")
            verify(flick !== null, "no rows viewport")
            // Walk down from the viewport to the item that holds the sections.
            // A Flickable wraps its content in a contentItem, so this has to be
            // a real descent, not one level.
            function findSectionHost(node) {
                if (!node)
                    return null
                if (item._countNamed(node, "traySubmenuSection") > 0)
                    return node
                for (var i = 0; i < node.children.length; i++) {
                    var hit = findSectionHost(node.children[i])
                    if (hit)
                        return hit
                }
                return null
            }
            var col = findSectionHost(flick)
            verify(col !== null, "nothing under the viewport holds the submenu sections")
            // The mapper is handed a bare name; prove that name is this item.
            var flickHost = findSectionHost(flick)
            compare(item._countNamed(flickHost, "traySubmenuSection") > 0, true,
                "the section host holds no sections, so the mapper cannot work")
        }
        function test_scrollableSubmenuRowStaysTappable() {
            // A scrollable submenu must still take taps: the Flickable claims
            // the press for dragging, so rows below it can go dead.
            Lazer.MotionTokens.reducedMotionOverride = true
            try {
                mouseMove(root, 380, 760); wait(20)
                mouseMove(root, 8, 700); wait(20)
                var parent = fakeEntry("More", { hasChildren: true })
                var item = makeMenu([fakeEntry("Top"), parent, fakeEntry("Bottom")])
                item.openSubmenu(parent, null)
                // Long submenu: the rows viewport must overflow.
                var many = []
                for (var i = 0; i < 20; i++)
                    many.push(fakeEntry("Child " + i))
                item.submenuEntries = many
                var ready = false
                for (var j = 0; j < 300 && !ready; j++) {
                    wait(10)
                    var f = findByName(item, "traySubmenuFlick")
                    ready = f && f.height > 0 && f.contentHeight > f.height
                }
                verify(ready, "submenu never became scrollable")
                var flick = findByName(item, "traySubmenuFlick")
                compare(flick.interactive, true, "viewport should be interactive")
                var point = flick.mapToItem(item, 40, 16)
                var dismissed = 0
                item.dismissRequested.connect(function() { dismissed++ })
                verify(pollAct(function() { hoverFresh(item, point.x, point.y) },
                    function() { return item.highlightedSubmenuRow !== null }),
                    "scrollable submenu row never highlighted")
                verify(pollAct(function() { mouseClick(item, point.x, point.y) },
                    function() { return dismissed === 1 }),
                    "scrollable submenu row click never landed")
                compare(dismissed, 1)
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }
        function test_faceOccludesSubmenu() {
            var item = makeMenu([fakeEntry("More", { hasChildren: true })])
            verify(item.submenuSurface.z < item.menuFace.z)
            // No fade: the opaque surface slides out from under the root face.
            compare(item.submenuSurface.opacity, 1)
            // Panels butt flush with no seam strip: the face always spans
            // exactly the card, open or closed, flipped or not.
            Lazer.MotionTokens.reducedMotionOverride = true
            var sub = fakeEntry("Sub", { hasChildren: true })
            var holder = makeMenu([sub])
            compare(holder.menuFace.x, -8)
            compare(holder.menuFace.width, holder.width + 16)
            holder.openSubmenu(sub, null)
            holder.submenuFlipped = true
            compare(holder.menuFace.x, -8)
            compare(holder.menuFace.width, holder.width + 16)
            holder.submenuFlipped = false
            compare(holder.menuFace.x, -8)
            compare(holder.menuFace.width, holder.width + 16)
            holder.closeSubmenu()
            compare(holder.menuFace.width, holder.width + 16)
            Lazer.MotionTokens.reducedMotionOverride = false
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
