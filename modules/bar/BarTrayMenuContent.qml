import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Window
import "./BarTrayMenuLogic.js" as Logic
import "../lazerbar" as Lazer

// Render the tray menu and its optional second-level surface.
Item {
    id: root
    objectName: "trayMenuRoot"
    implicitWidth: 244
    // The root may widen into an input canvas for the overflowing submenu;
    // primary visuals stay on this fixed column width.
    readonly property real primaryMenuWidth: implicitWidth
    implicitHeight: {
        if (emptyStateVisible) return 32
        if (menuLoading) return Math.max(heldHeight, 72)
        return Math.max(heldHeight, menuFlick.height,
            submenuNeedsHeight ? submenuSurface.height : 0)
    }

    // No Behavior here: batch arrivals settle while the host reveal is held
    // at progress 0 (invisible), and late batches are smoothed by the host's
    // own height motion. An animated implicitHeight under a running reveal
    // stretches the content mid-slide and reads as bounce.

    property var menuHandle: null
    property bool useStubEntries: false
    property var trayItem: null
    readonly property var resolvedMenuHandle: menuHandle !== null && menuHandle !== undefined
        ? menuHandle : (trayItem ? trayItem.menu : null)
    readonly property int liveCount: rootOpenerLoader.item ? rootOpenerLoader.item.count : 0
    readonly property var liveValues: rootOpenerLoader.item ? rootOpenerLoader.item.values : []
    property var entries: null
    // A new tray icon brings a new menu: retract any submenu left over from
    // the previous icon instead of sliding it under the fresh list. The
    // close keeps its animation (data releases at progress 0) so the host
    // width morphs instead of snapping mid-exchange.
    onMenuHandleChanged: closeSubmenu()
    onTrayItemChanged: closeSubmenu()
    onEntriesChanged: closeSubmenu()
    readonly property bool stubEntriesActive: useStubEntries
        || (entries !== null && entries !== undefined && Logic.entryList(entries).length > 0)
    readonly property var entryModel: stubEntriesActive
        ? Logic.entryList(entries)
        : Logic.entryList(liveValues)
    // Settings-style section blocks split at separators; gaps between
    // blocks (not divider lines) carry the grouping. NOTE: native opener
    // lists are QML sequences, not JS arrays, and .pragma library code
    // cannot index them (every lookup yields undefined). Group them here
    // in QML context where [i] works; plain arrays still go through Logic.
    function sectionize(source) {
        if (Array.isArray(source))
            return Logic.sectionList(source)
        var sections = []
        var current = null
        if (!source || typeof source.length !== "number")
            return sections
        for (var i = 0; i < source.length; i++) {
            var entry = source[i]
            if (!entry || Logic.isSeparator(entry)) {
                current = null
                continue
            }
            if (!current) {
                current = []
                sections.push(current)
            }
            current.push(entry)
        }
        return sections
    }
    readonly property var menuSections: sectionize(stubEntriesActive
        ? entryModel
        : (rootOpenerLoader.item ? rootOpenerLoader.item.values : []))
    readonly property var submenuSections: sectionize(stubEntriesActive
        ? submenuEntries
        : (submenuOpenerLoader.item ? submenuOpenerLoader.item.values : []))
    onSubmenuSectionsChanged: resolveSubHoverFromMemory()
    readonly property bool menuLoading: resolvedMenuHandle != null && !stubEntriesActive
        && liveCount === 0
    readonly property bool emptyStateVisible: resolvedMenuHandle === null
        || (stubEntriesActive ? rowCount === 0 : (liveCount === 0 && !menuLoading))
    readonly property int rowCount: stubEntriesActive ? Logic.entryList(entries).length : liveCount

    property string submenuPhase: "closed"
    property real submenuProgress: 0
    // Rows take hover/taps only once fully revealed; while sliding under
    // the opaque face they must never highlight beneath the primary rows.
    readonly property bool submenuInteractable: submenuPhase === "open"
    // Maps a content Y to its row within a section column, with strict row
    // bounds: gaps map to nothing. Returns { entry, row, offset } with the
    // offset measured from the row top for edge tolerance.
    function rowAtContentY(column, sectionName, y) {
        var rowsSeen = 0
        var kids = column.children
        for (var i = 0; i < kids.length; i++) {
            var sec = kids[i]
            if (!sec || sec.objectName !== sectionName)
                continue
            if (y < sec.y)
                break
            var inner = null
            var skids = sec.children
            for (var k = 0; k < skids.length; k++) {
                if (skids[k] && skids[k].objectName === sectionName + "Column") {
                    inner = skids[k]
                    break
                }
            }
            if (!inner)
                continue
            var rkids = inner.children
            for (var r = 0; r < rkids.length; r++) {
                var row = rkids[r]
                if (!row || row.objectName !== "trayMenuRow")
                    continue
                rowsSeen++
                var top = sec.y + row.y
                if (y < top)
                    break
                if (y < top + row.height)
                    return { entry: row.modelData, row: row, offset: y - top, rowsSeen: rowsSeen }
            }
        }
        return { entry: null, row: null, offset: -1, rowsSeen: rowsSeen }
    }
    function entryAtContentY(y) {
        return rowAtContentY(menuColumn, "trayMenuSection", y)
    }
    property var hoverMappedEntry: null
    // Sole logic owner for primary hover: acts only when the mapped row
    // changes, so sweeps cost one act per row crossed, never per pixel.
    // Edge tolerance against boundary jitter (proven 1px oscillation in
    // production logs): summoning needs the cursor 8px deep inside the row
    // while closed/closing. Retracting stays instant at any offset, and an
    // already-open submenu keeps redirecting without tolerance.
    readonly property real submenuEdgeTolerance: 8
    function actOnMappedRow(mapped) {
        var entry = mapped ? mapped.entry : null
        if (entry === hoverMappedEntry)
            return
        if (entry && Logic.shouldOpenSubmenu(entry)
                && (submenuPhase === "closed" || submenuPhase === "closing")
                && mapped.row && (mapped.offset < submenuEdgeTolerance
                    || mapped.offset > mapped.row.height - submenuEdgeTolerance))
            return
        hoverMappedEntry = entry
        if (entry && Logic.shouldOpenSubmenu(entry)) {
            openSubmenu(entry, mapped.row)
            return
        }
        // Retract only a settled submenu: gaps/plains crossed while it is
        // still opening are travel paths toward it, never abort signals.
        // (Popup close still retracts via closeSubmenu directly.)
        if (submenuPhase === "open")
            closeSubmenu()
    }
    property var submenuEntry: null
    property Item submenuAnchorRow: null
    property int submenuAnchorLevel: submenuAnchorRow ? submenuAnchorRow.level : 0
    property var submenuEntries: []
    // Second-level placement: the panel hangs from its anchor row (title
    // top flush with the anchor bottom edge) and extends downward,
    // bottom-clamped to the primary flick so the popup never grows.
    // Longer submenus scroll inside; when the anchor sits too low the
    // panel shifts up instead. The rows viewport keeps title + padding
    // + at least one row, so hover and click delivery stay alive.
    property real submenuAnchorBottomY: 0
    // The trigger row's top edge. The panel is positioned so its FIRST ROW
    // lands exactly here, which is the whole point: moving the pointer right
    // off a row must land on that row, because "move right" is the gesture
    // every menu trains. With the panel hanging below the row's bottom edge
    // instead, the travel line sat 11px above the panel and 67px above the
    // first row, so traversing sideways could never highlight or activate
    // anything — the panel was visible and completely inert.
    property real submenuAnchorTopY: 0
    // Space below the anchor row inside the primary flick.
    readonly property real submenuAvailHeight: Math.max(0, menuFlick.height - submenuAnchorBottomY)
    // Full rows height (title/padding excluded), at least one row.
    readonly property real submenuBodyFull: Math.max(32, submenuColumn.implicitHeight)
    // Minimum surface: title + padding + one row + padding.
    readonly property real submenuMinSurface: 48 + root.submenuPad + 32 + root.submenuPad
    readonly property real submenuTitleHeight: 48
    // Surface spans from the anchor down while it fits; otherwise it
    // shifts up to stay inside the primary flick (tiny primaries may
    // still exceed below by a bounded strip, keeping input alive).
    readonly property real submenuSurfaceHeight: submenuAvailHeight >= submenuMinSurface
        ? Math.min(56 + submenuBodyFull + 8, submenuAvailHeight)
        : submenuMinSurface
    // Position: the title occupies the strip ABOVE the trigger row so the rows
    // start on it. Two clamps keep it inside the menu — never above the top
    // row, never past the bottom of the flick.
    readonly property real submenuSurfaceY: Math.max(0, Math.min(
        submenuAnchorTopY - submenuTitleHeight,
        menuFlick.height - submenuSurfaceHeight))
    property real heldHeight: 420
    property real rawColumnHeight: menuColumn.implicitHeight
    property real submenuAnimationTarget: 0
    // Flip the second level to the left when the tray icon sits at the
    // screen edge: expanding right would shove the primary column left.
    property bool submenuFlipped: false
    property bool popsRight: true
    onSubmenuFlippedChanged: popsRight = !submenuFlipped
    // Submenu panel mirrors the primary panel: same button width, same 8
    // padding on the outer edges. The 8px meeting gap belongs to the visual
    // panels; the catcher below still owns that gap so traversal stays live.
    readonly property real submenuPad: 8
    // Container growth covers the surface exactly: it butts flush against
    // the primary panel, so growth equals the surface width. (Travel spans
    // one pad more because the hidden position tucks the surface that pad
    // deeper under the face.)
    readonly property real extraWidth: submenuProgress > 0 ? submenuSurface.width : 0
    readonly property alias submenuSurface: submenuSurface
    readonly property alias submenuAnimation: submenuAnimation
    readonly property alias menuFace: menuFace
    readonly property alias submenuViewport: submenuFlick
    // Input-side alias: the column catcher is the second level's only input
    // owner, so its geometry is what diagnostics need to judge an arrival.
    readonly property alias submenuColumn: submenuColumnCatcher
    readonly property real maxMenuHeight: Screen.desktopAvailableHeight > 0
        ? Math.max(180, Screen.desktopAvailableHeight * 0.7) : 420
    signal dismissRequested()

    // Anchor bottom edge in root coords for the submenu panel. Row
    // delegates are rebuilt on model changes, so resolve defensively and
    // keep the last good anchor when the row is gone.
    function anchorBottomFromRow(row) {
        try {
            var y = row.mapToItem(root, 0, row.height).y
            if (isFinite(y))
                return y
        } catch (err) {}
        return null
    }
    // The trigger row's TOP edge, which is what the first submenu row has to
    // land on. Only the bottom edge was needed while the panel hung below the
    // row; aligning rows needs the top.
    function anchorTopFromRow(row) {
        try {
            var y = row.mapToItem(root, 0, 0).y
            if (isFinite(y))
                return y
        } catch (err) {}
        return null
    }

    function activateEntry(entry, level, row) {
        if (!Logic.isEnabled(entry))
            return
        if (Logic.shouldOpenSubmenu(entry)) {
            openSubmenu(entry, row || null)
            return
        }
        try {
            if (typeof entry.triggered === "function")
                entry.triggered()
        } catch (err) {}
        if (Logic.shouldDismissOnTrigger(entry)) {
            // Retract the second level on the click frame so a submenu-leaf
            // activation exits with the shared retract motion (data releases
            // at progress 0) instead of vanishing with the host. No-op when
            // no submenu is open.
            dismissingForLeaf = true
            closeSubmenu()
            dismissRequested()
        }
    }

    function openSubmenu(entry, row) {
        if (!Logic.shouldOpenSubmenu(entry))
            return
        // Pin the panel to the anchor row; a gone row keeps the last pin.
        function pinAnchor(candidate) {
            if (candidate) {
                var bottom = anchorBottomFromRow(candidate)
                if (bottom !== null)
                    submenuAnchorBottomY = bottom
                var top = anchorTopFromRow(candidate)
                if (top !== null)
                    submenuAnchorTopY = top
                submenuAnchorRow = candidate
            }
        }
        // Redirect without replaying reveal when already visible.
        if ((submenuPhase === "open" || submenuPhase === "opening") && submenuEntry === entry) {
            pinAnchor(row)
            return
        }
        if (submenuPhase === "open" || submenuPhase === "opening") {
            submenuEntry = entry
            pinAnchor(row)
            return
        }
        submenuEntry = entry
        pinAnchor(row)
        // A fresh summon from hover clears the leaf-dismiss guard; the bounce
        // path never reaches here (transitToSubmenu returns early instead).
        dismissingForLeaf = false
        // Match the primary content layer: 500ms, OutCubic in.
        submenuAnimation.duration = Lazer.MotionTokens.reducedMotion ? 0 : Lazer.MotionTokens.settingsSidebarFade
        submenuAnimation.easing.type = Easing.OutCubic
        submenuAnimationTarget = 1
        if (Lazer.MotionTokens.reducedMotion) {
            submenuProgress = 1
            submenuPhase = "open"
            submenuAnimation.restart()
            return
        }
        submenuPhase = "opening"
        submenuAnimation.restart()
    }

    function closeSubmenu() {
        hoverMappedEntry = null
        if (submenuEntry === null && submenuProgress === 0)
            return
        // Already retracting: restarting per row would stall the animation
        // forever under a moving cursor, reading as stuck half-out.
        if (submenuPhase === "closing")
            return
        // Match the primary content layer: 500ms, InOutQuad out.
        submenuAnimation.duration = Lazer.MotionTokens.reducedMotion ? 0 : Lazer.MotionTokens.settingsSidebarFade
        submenuAnimation.easing.type = Easing.InOutQuad
        submenuAnimationTarget = 0
        if (Lazer.MotionTokens.reducedMotion) {
            submenuPhase = "closing"
            submenuProgress = 0
            submenuAnimation.restart()
            return
        }
        submenuPhase = "closing"
        submenuAnimation.restart()
    }

    // Keep a stable panel while opener data is still arriving asynchronously.
    onRawColumnHeightChanged: noteColumnHeight(rawColumnHeight)

    function noteColumnHeight(value) {
        heldHeight = Logic.heldHeight(Math.min(Number(value), maxMenuHeight), heldHeight)
    }

    // Native DBus menus are loaded only when a real menu handle is present.
    Loader {
        id: rootOpenerLoader
        active: !root.stubEntriesActive && root.resolvedMenuHandle != null
        source: "QsMenuOpenerBridge.qml"
        onLoaded: if (item) item.menu = root.resolvedMenuHandle
    }

    Binding {
        target: rootOpenerLoader.item
        property: "menu"
        value: root.resolvedMenuHandle
        when: rootOpenerLoader.item != null
    }

    // Submenus use a second opener because each QsMenuEntry owns its own handle.
    Loader {
        id: submenuOpenerLoader
        active: !root.stubEntriesActive && root.submenuEntry != null
        source: "QsMenuOpenerBridge.qml"
        onLoaded: if (item) item.menu = root.submenuEntry
    }

    Binding {
        target: submenuOpenerLoader.item
        property: "menu"
        value: root.submenuEntry
        when: submenuOpenerLoader.item != null
    }

    // Opaque root face hides the submenu until it has slid clear. It sits
    // flush with the card (same span as the blue background) since the
    // panels butt directly with no seam strip between them.
    Rectangle {
        id: menuFace
        objectName: "trayMenuFace"
        z: 2
        x: -root.submenuPad
        width: root.primaryMenuWidth + root.submenuPad * 2
        height: menuFlick.height
        color: Lazer.LazerTheme.settingsSection
    }

    // Empty-state label for an unavailable or empty tray menu.
    Text {
        id: emptyState
        objectName: "trayEmptyState"
        visible: emptyStateVisible
        z: 4
        text: "No menu items"
        color: Lazer.LazerTheme.textMuted
        font.pixelSize: 13
        anchors.left: parent.left
        anchors.margins: 16
        anchors.verticalCenter: parent.verticalCenter
    }

    // Sole hover owner for the primary list, stacked above the rows: only
    // the topmost chain receives hover, so a catcher below would stay deaf
    // (proven by probe). It maps every pixel to its row (gaps belong to
    // the row above) and drives both highlight and logic; clicks pass
    // through (NoButton). Horizontal travel to the submenu changes no row,
    // so arrivals stay safe.
    MouseArea {
        objectName: "trayMenuHoverCatcher"
        anchors.fill: menuFlick
        z: 4
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        // NOTE: onEntered carries no mouse parameter; use the mouseX/mouseY
        // item properties instead (valid in any handler).
        onEntered: { root.traceEvent("primary", "enter", mouseX, mouseY); root.rememberCursor(mouseX, mouseY); root.hoverAtCatcher(mouseY + menuFlick.contentY) }
        onPositionChanged: { root.traceEvent("primary", "move", mouseX, mouseY); root.rememberCursor(mouseX, mouseY); root.hoverAtCatcher(mouseY + menuFlick.contentY) }
        onExited: { root.traceEvent("primary", "exit", mouseX, mouseY); root.hoverLeaveCatcher() }
    }
    // Submenu column: the whole band beside the primary is one input surface,
    // not just the painted panel. The panel hangs from its trigger row's bottom
    // edge, so the travel line (the row's own height) and the title band sit
    // above it: with input owned only by the panel, a pointer crossing right
    // along the row passed through a dead gap, the primary's exit wiped the
    // memory on the way out, and nothing re-armed it — no highlight and no tap
    // until the pointer came back down into the rows. A fast crossing also
    // skipped the old 8px transit strip entirely, since a single motion event
    // never rests inside it.
    //
    // This catcher is always alive, so it also covers the cold first-open
    // window (the panel is hidden until its rows arrive) and makes the
    // panel->bridge handoff a non-event. Taps pass through to the rows.
    MouseArea {
        id: submenuColumnCatcher
        objectName: "traySubmenuColumnCatcher"
        x: root.submenuFlipped ? -(submenuSurface.width + root.submenuPad) : menuFlick.width
        y: 0
        width: submenuSurface.width + root.submenuPad
        // Spans the primary's rows and the panel's full extent: on a short
        // primary the panel's minimum surface reaches below the last row, and
        // input must still be live where it is painted.
        height: Math.max(menuFlick.height, submenuSurface.y + submenuSurface.height)
        z: 4
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        // Arrival handling. The bounce requires real movement inside the band:
        // the band's extent follows the panel, so opening or retracting it can
        // slide the boundary under a stationary pointer, and Qt re-delivers a
        // position event at the same spot — bouncing on that would pull a
        // retracting submenu straight back open.
        property int lastColumnX: -1
        property int lastColumnY: -1
        onEntered: {
            // Seed with the crossing point itself, so the position event Qt
            // delivers right after the enter does not read as movement.
            lastColumnX = mouseX
            lastColumnY = mouseY
            root.traceEvent("band", "enter", mouseX, mouseY)
            if (debugLeave)
                console.log("[afloat:TrayDebug] enter column-band at " + mouseX + "," + mouseY)
            root.hoverAtSubColumn(mouseX, mouseY)
        }
        onPositionChanged: {
            var moved = mouseX !== lastColumnX || mouseY !== lastColumnY
            lastColumnX = mouseX
            lastColumnY = mouseY
            root.traceEvent("band", "move", mouseX, mouseY)
            root.hoverAtSubColumn(mouseX, mouseY)
            if (moved)
                root.transitToSubmenu()
        }
        onExited: {
            root.traceEvent("band", "exit", mouseX, mouseY)
            root.highlightedSubmenuRow = null
            // Same reasoning as the primary catcher: report the position while
            // it is still known, so the host can check it against the region.
            if (root.lastCursorX >= 0)
                root.pointerDeparted(root.lastCursorX, root.lastCursorY, "column-band")
            root.forgetCursor()
            if (root.debugLeave)
                console.log("[afloat:TrayDebug] leave column-band at " + mouseX + "," + mouseY)
        }
    }
    // Event-level hover trace, off unless diagnostics are on. Sampled snapshots
    // at 120ms cannot see a delivery that stops between two samples, and "the
    // panel is visible but nothing on it reacts" is exactly that shape of bug.
    // Each owner reports its first and last event, so a chain that breaks shows
    // up as the last owner that spoke — which is the only thing that
    // distinguishes "Qt never delivered" from "we mishandled it".
    property bool debugEvents: false
    property int _evPrimary: 0
    property int _evBand: 0
    property int _evPanel: 0
    property string _evFirstPrimary: "none"
    property string _evFirstBand: "none"
    property string _evFirstPanel: "none"
    function traceEvent(owner, kind, lx, ly) {
        if (!debugEvents)
            return
        var n = owner === "primary" ? root._evPrimary
            : owner === "band" ? root._evBand : root._evPanel
        if (owner === "primary") {
            root._evPrimary += 1
            if (root._evFirstPrimary === "none")
                root._evFirstPrimary = kind + "@" + lx + "," + ly
        } else if (owner === "band") {
            root._evBand += 1
            if (root._evFirstBand === "none")
                root._evFirstBand = kind + "@" + lx + "," + ly
        } else {
            root._evPanel += 1
            if (root._evFirstPanel === "none")
                root._evFirstPanel = kind + "@" + lx + "," + ly
        }
        console.log("[afloat:TrayEvent] " + owner + " " + kind + " at " + lx + "," + ly
            + " n=" + n)
    }

    function transitToSubmenu() {
        // A leaf activation dismisses the whole popup; a transit arrival
        // landing in that window must not bounce the retracting submenu back
        // open (the click itself lands inside the column band).
        if (dismissingForLeaf)
            return
        if (submenuEntry && submenuPhase !== "open")
            openSubmenu(submenuEntry, submenuAnchorRow)
    }
    // Set between a leaf activation and the next genuine summon; see
    // transitToSubmenu. Cleared when a hover summons the panel again or when
    // the retraction has fully released.
    property bool dismissingForLeaf: false
    // Submenu hover state lives here at root level: functions nested inside
    // the surface are unreachable via root.* and fail silently.
    property Item highlightedSubmenuRow: null
        // Column-relative hover (the catcher spans the whole band beside the
        // primary): refresh the root pointer memory, then map into the rows
        // viewport. Points above the panel or past its rows map to no row, so
        // travelling along the trigger row keeps the memory without lighting
        // anything, and dropping into the rows lights the row under the cursor.
        function hoverAtSubColumn(columnX, columnY) {
            // Catcher-relative in, root-relative out: the surface and the
            // memory both live in root coordinates.
            var rootX = submenuColumnCatcher.x + columnX
            var rootY = submenuColumnCatcher.y + columnY
            rememberCursor(rootX, rootY)
            highlightedSubmenuRow = null
            if (!submenuSurface.visible)
                return
            var sx = rootX - submenuSurface.x
            var sy = rootY - submenuSurface.y
            var inX = submenuFlipped ? (sx >= 0 && sx <= submenuSurface.width + 12)
                : (sx >= -12 && sx <= submenuSurface.width)
            var fy = sy - submenuFlick.y + submenuFlick.contentY
            if (!inX || fy < 0 || fy >= submenuFlick.height)
                return
            // Which item does the bare name `submenuColumn` resolve to HERE?
            // It is declared twice — the input band is exported as a property
            // alias of that name, and the rows Column carries it as an id. The
            // mapper needs the Column; if the alias wins, it receives the band
            // and finds no sections at all, on any data path. Reporting the
            // inventory settles it without guessing which one bound.
            var scope = submenuColumn
            var m = rowAtContentY(scope, "traySubmenuSection", fy)
            if (debugEvents && (!m.row || !m.rowsSeen)) {
                console.log("[afloat:TrayMap] fy=" + Math.round(fy)
                    + " scope=" + (scope && scope.objectName ? scope.objectName
                        : String(scope))
                    + " kids=" + (scope ? scope.children.length : -1)
                    + " sections=" + (scope ? root._countNamed(scope, "traySubmenuSection") : -1)
                    + " rows=" + m.rowsSeen)
            }
            highlightedSubmenuRow = m.row
        }
    // How many direct children carry this objectName — the mapper's first
    // filter. Zero here with a visible panel means it was handed the wrong
    // scope, not that the rows are missing.
    function _countNamed(scope, name) {
        var n = 0
        for (var i = 0; i < scope.children.length; i++) {
            if (scope.children[i] && scope.children[i].objectName === name)
                n++
        }
        return n
    }
    // Re-resolve under a stationary cursor from memory (root coords): the
    // reveal sliding under it and data rebuilds generate no hover events.
    // 12px tolerance toward the primary side covers arrivals parked on the
    // bridge strip.
    // Re-resolve under a stationary cursor from memory. Delegates may not
    // exist yet when this runs (model changes precede instantiation), so a
    // miss with no rows seen retries; a miss with rows present is a genuine
    // gap and clears. The retry budget spans the cold first-open batch: the
    // DBus fetch lands, then the delegates are created and positioned over
    // several frames, and the pointer never moves in between.
    readonly property int submenuResolveRetries: 30
    function resolveSubHoverFromMemory(retry) {
        retry = retry || 0
        if (lastCursorX < 0)
            return
        var sx = lastCursorX - submenuSurface.x
        var sy = lastCursorY - submenuSurface.y
        var inX = submenuFlipped ? (sx >= 0 && sx <= submenuSurface.width + 12)
            : (sx >= -12 && sx <= submenuSurface.width)
        var fx = sx - submenuFlick.x
        var fy = sy - submenuFlick.y
        if (!inX || fy < 0 || fy >= submenuFlick.height) {
            // A laid-out viewport lags delegate creation by frames under
            // load; retry briefly instead of wiping a live highlight.
            if (submenuFlick.height <= 0 && retry < submenuResolveRetries)
                Qt.callLater(function() { root.resolveSubHoverFromMemory(retry + 1) })
            else
                highlightedSubmenuRow = null
            return
        }
        var m = rowAtContentY(submenuColumn, "traySubmenuSection", fy + submenuFlick.contentY)
        if (m.row) {
            highlightedSubmenuRow = m.row
            return
        }
        if (m.rowsSeen === 0 && retry < submenuResolveRetries)
            Qt.callLater(function() { root.resolveSubHoverFromMemory(retry + 1) })
        else
            highlightedSubmenuRow = null
    }
    function resolveHoverFromMemory(retry) {
        retry = retry || 0
        if (lastCursorX < 0)
            return
        if (lastCursorX < 0 || lastCursorX >= menuFlick.width
                || lastCursorY < 0 || lastCursorY >= menuFlick.height) {
            highlightedRow = null
            return
        }
        var pm = rowAtContentY(menuColumn, "trayMenuSection", lastCursorY + menuFlick.contentY)
        if (pm.row) {
            highlightedRow = pm.row
            return
        }
        if (pm.rowsSeen === 0 && retry < 5)
            Qt.callLater(function() { root.resolveHoverFromMemory(retry + 1) })
        else
            highlightedRow = null
    }
    // Last cursor position in root coords, refreshed by every catcher event.
    // Item motion/appearance generates no hover events, so open-finish and
    // data rebuilds re-resolve from memory instead of losing the cursor.
    property real lastCursorX: -1
    property real lastCursorY: -1
    // Hover-exit tracing, off unless diagnostics are on. A popup that closes
    // with no owner holding hover is either the user leaving or the compositor
    // dropping focus; which exit fired, and where the pointer was, tells them
    // apart.
    property bool debugLeave: false
    // Set once the host has subscribed to pointerDeparted. The tray instance is
    // replaced when the popup changes intent, so the host re-wires on each new
    // one rather than assuming a single instance.
    property bool departuresWired: false
    function rememberCursor(x, y) { lastCursorX = x; lastCursorY = y }
    function forgetCursor() { lastCursorX = -1; lastCursorY = -1 }
    // Row currently under the cursor, owned by the catcher for highlight.
    property Item highlightedRow: null
    function hoverAtCatcher(contentY) {
        var mapped = entryAtContentY(contentY)
        highlightedRow = mapped.row
        actOnMappedRow(mapped)
    }
    function hoverLeaveCatcher() {
        // Clear highlight only: leaving toward the submenu must not act
        // (arrivals would die). Stale intent resets in closeSubmenu.
        if (debugLeave)
            console.log("[afloat:TrayDebug] leave primary-catcher mem="
                + lastCursorX + "," + lastCursorY)
        highlightedRow = null
        // The memory is shared with the second level, and this exit is
        // delivered after the arrival it collides with: crossing from the
        // rows into the panel/bridge fires both, and wiping here strands the
        // submenu highlight (the cold first-open path parks the pointer in
        // that area for the whole fetch, so nothing re-arms it). Departures
        // that really leave the second level are handled by its own catcher.
        if (pointerOverSubmenu())
            return
        // Announce the departure BEFORE forgetting. The host has to judge this
        // exit against the input region, and forgetCursor() would leave it
        // unable to tell a real departure from a compositor-side leave that
        // happened while the pointer was still over us.
        // Emitted only when a position is actually known: this menu's content
        // slides in from the right, so a legitimate pointer x can be negative
        // and must not be mistaken for "no pointer".
        if (lastCursorX >= 0)
            pointerDeparted(lastCursorX, lastCursorY, "primary-catcher")
        forgetCursor()
    }
    // Last known pointer position when this surface believes the pointer left.
    // The host compares it against the committed input region: inside means the
    // leave did not come from the user, and closing on it is what kills the
    // first expand.
    signal pointerDeparted(real x, real y, string source)
    // Is the remembered point still over the second level's column (the input
    // band beside the primary)? Used to decide whether a primary exit means
    // "left the menu" or "moved across to the submenu".
    function pointerOverSubmenu() {
        if (lastCursorX < 0 || submenuProgress <= 0.01)
            return false
        var column = submenuColumnCatcher
        return lastCursorX >= column.x && lastCursorX <= column.x + column.width
            && lastCursorY >= column.y && lastCursorY <= column.y + column.height
    }
    // Primary rebuilds (cold batches) under a stationary cursor.
    onMenuSectionsChanged: resolveHoverFromMemory()

    // Root entries scroll inside the bounded visible menu surface.
    Flickable {
        id: menuFlick
        objectName: "trayMenuFlick"
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.primaryMenuWidth
        height: Math.min(menuColumn.implicitHeight, maxMenuHeight)
        contentHeight: menuColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        z: 3

        // Root-level entries are grouped into settings-style section blocks
        // split at separators; the gaps between blocks separate groups.
        Column {
            id: menuColumn
            objectName: "trayMenuColumn"
            width: menuFlick.width
            spacing: 4
            onHeightChanged: Qt.callLater(root.resolveHoverFromMemory)

            Repeater {
                model: root.menuSections
                onItemAdded: Qt.callLater(root.resolveHoverFromMemory)
                onItemRemoved: Qt.callLater(root.resolveHoverFromMemory)

                delegate: Rectangle {
                    required property var modelData
                    objectName: "trayMenuSection"
                    width: menuColumn.width
                    height: sectionColumn.implicitHeight
                    color: Lazer.LazerTheme.settingsPanel

                    Column {
                        id: sectionColumn
                        objectName: "trayMenuSectionColumn"
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: modelData

                            delegate: Item {
                                id: rootRow
                                required property var modelData
                                property int level: 1
                                width: sectionColumn.width
                                height: 32
                                objectName: "trayMenuRow"

                                // Interactive root menu row; highlight follows
                                // the catcher-owned row, rows carry no hover
                                // handlers of their own.
                                Rectangle {
                                id: rowSurface
                                objectName: "trayMenuRowSurface"
                                anchors.fill: parent
                                radius: 4
                                color: root.highlightedRow === rootRow ? Lazer.LazerTheme.settingsCardHover : Lazer.LazerTheme.settingsCard
                                opacity: Logic.isEnabled(modelData) ? 1 : Lazer.MotionTokens.disabledOpacity

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        elide: Text.ElideRight
                        text: Logic.labelOf(modelData)
                        color: Lazer.LazerTheme.textPrimary
                        font.pixelSize: 13
                    }

                    Text {
                        visible: Logic.isChecked(modelData)
                        text: "✓"
                        anchors.right: parent.right
                        anchors.rightMargin: Logic.hasChildren(modelData) ? 30 : 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Lazer.LazerTheme.settingsAccent
                        font.pixelSize: 14
                    }

                    Text {
                        visible: Logic.hasChildren(modelData)
                        text: ">"
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Lazer.LazerTheme.textMuted
                        font.pixelSize: 14
                    }

                    Rectangle {
                        id: clickFlash
                        anchors.fill: parent
                        radius: parent.radius
                        color: Lazer.LazerTheme.textPrimary
                        opacity: 0
                    }



                    TapHandler {
                        onTapped: {
                            clickFlash.opacity = Lazer.MotionTokens.clickFlashOpacity
                            clickFlashFade.restart()
                            activateEntry(modelData, level, rootRow)
                        }
                    }

                    NumberAnimation {
                        id: clickFlashFade
                        target: clickFlash
                        property: "opacity"
                        to: 0
                        duration: Lazer.MotionTokens.clickFlashDuration
                        easing.type: Lazer.MotionTokens.clickFlashEasing
                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Second level only renders when it actually has rows. Hovering a row
    // whose handle reports children but fetches none must not pop a blank
    // panel; closing keeps its last frame until progress hits zero.
    readonly property bool hasSubmenuContent: stubEntriesActive
        ? Logic.entryList(submenuEntries).length > 0
        : (submenuOpenerLoader.item ? submenuOpenerLoader.item.count > 0 : false)
    readonly property bool submenuNeedsHeight: submenuProgress > 0.01
        && (hasSubmenuContent || submenuPhase === "closing")
    // Preserve the second-level surface during its closing transition.
    // The panel hangs from the anchor row: title top flush with the
    // anchor bottom edge, content extending downward inside the primary
    // vertical range.
    Rectangle {
        id: submenuSurface
        objectName: "traySubmenuSurface"
        z: 1
        visible: submenuProgress > 0.01 && (hasSubmenuContent || submenuPhase === "closing")
        width: root.primaryMenuWidth
        height: submenuNeedsHeight ? submenuSurfaceHeight : menuFlick.height
        // Restore the visual 8px meeting gap. The input catcher deliberately
        // starts at the primary edge and spans this gap, so the visual spacing
        // does not recreate the old dead input seam.
        x: submenuFlipped
            ? -(width + root.submenuPad) : root.primaryMenuWidth + root.submenuPad
        // Panel top tracks the anchor from the first frame (even before
        // rows arrive) so cold-fetch cursor memory stays valid across
        // the batch; hidden anyway until content lands.
        y: submenuSurfaceY
        color: Lazer.LazerTheme.settingsSection
        clip: true

        // Submenu title: full-width settingsRail block, 48 high, pinned to
        // the panel top so its top edge meets the anchor row bottom edge.
        // Bold 13px label on 12px margins.
        Rectangle {
            objectName: "traySubmenuTitleBlock"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: submenuTitleHeight
            color: Lazer.LazerTheme.settingsRail

            Text {
                objectName: "traySubmenuTitle"
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Logic.submenuTitle(submenuEntry)
                color: Lazer.LazerTheme.textPrimary
                font.pixelSize: 13
                font.bold: true
            }
        }

        // Does the VISIBLE panel receive pointer events at all? This is the one
        // measurement that separates "the panel is dead" from "the panel is live
        // and the mapping is wrong", and the two look identical from outside.
        // Non-blocking so it observes alongside the rows' handlers rather than
        // competing with them for delivery.
        HoverHandler {
            id: submenuPanelProbe
            blocking: false
            onHoveredChanged: {
                root.traceEvent("panel", hovered ? "enter" : "exit", -1, -1)
            }
            onPointChanged: function(point) {
                root.traceEvent("panel", "move", Math.round(point.position.x),
                    Math.round(point.position.y))
            }
        }

        // Submenu hover lives one level up: traySubmenuColumnCatcher owns the
        // whole band beside the primary, so this panel carries display only
        // (title, rows, their tap handlers). Ungated by phase — hidden rows
        // paint under the opaque face anyway; taps stay gated on phase.
        // Cold batches rebuild delegates under a stationary cursor: recompute
        // from remembered position instead of losing the highlight. (Handled
        // at root level; a nested Connections here proved unreliable.)

        // Child entries remain held during closing and update from the live opener.
        // Rows start below the title with the outer-edge padding rhythm.
        Flickable {
            id: submenuFlick
            objectName: "traySubmenuFlick"
            // Padding lives on the outer edge; the panel's 8px meeting gap is
            // owned by the catcher rather than the row viewport.
            anchors.left: parent.left
            anchors.leftMargin: root.submenuFlipped ? root.submenuPad : 0
            anchors.right: parent.right
            anchors.rightMargin: root.submenuFlipped ? 0 : root.submenuPad
            anchors.top: parent.top
            anchors.topMargin: 48 + root.submenuPad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.submenuPad
            contentHeight: submenuColumn.implicitHeight
            clip: true
            interactive: contentHeight > height
            Column {
                id: submenuColumn
                width: parent.width
                spacing: 4
                // Height settles once laid-out delegates are positioned;
                // re-resolve then (existence alone leaves y unassigned).
                onHeightChanged: Qt.callLater(root.resolveSubHoverFromMemory)
                Repeater {
                    model: root.submenuSections
                    // Delegates materialize asynchronously after the model
                    // changes; re-resolve here (not on model change, which
                    // fires before any delegate exists).
                    onItemAdded: Qt.callLater(root.resolveSubHoverFromMemory)
                    onItemRemoved: Qt.callLater(root.resolveSubHoverFromMemory)
                    delegate: Rectangle {
                        required property var modelData
                        objectName: "traySubmenuSection"
                        width: submenuColumn.width
                        height: submenuSectionColumn.implicitHeight
                        color: Lazer.LazerTheme.settingsPanel
                        Column {
                            id: submenuSectionColumn
                            objectName: "traySubmenuSectionColumn"
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: modelData
                                delegate: Item {
                                    id: subRow
                                    required property var modelData
                                    property int level: 2
                                    width: submenuSectionColumn.width
                                    height: 32
                                    objectName: "trayMenuRow"
                                    Rectangle {
                                        objectName: "trayMenuRowSurface"
                                        anchors.fill: parent
                                        radius: 4
                                        color: root.highlightedSubmenuRow === subRow ? Lazer.LazerTheme.settingsCardHover : Lazer.LazerTheme.settingsCard
                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Logic.labelOf(modelData)
                                            color: Lazer.LazerTheme.textPrimary
                                            font.pixelSize: 13
                                        }
                                        TapHandler {
                                            enabled: root.submenuInteractable
                                            onTapped: activateEntry(modelData, 2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Drawer from under the primary: same slide as the content layer,
        // but horizontal and fully opaque throughout. Rest position is
        // beside the root; the travel points back toward the root so the
        // start position stacks underneath it, hidden by the opaque face.
        opacity: 1
        transform: Translate {
            // NOTE: `parent` does not resolve to the menu root inside a
            // transform scope, so use the surface width explicitly.
            x: (root.popsRight ? -1 : 1) * (submenuSurface.width + root.submenuPad) * (1 - root.submenuProgress)
        }

    }

    // Keep pointer traversal alive across the small root/submenu gap.
    Item {
        objectName: "traySubmenuBridge"
        z: 0
        x: submenuFlipped ? -root.submenuPad : root.primaryMenuWidth
        y: submenuSurface.y
        width: submenuProgress > 0 ? root.submenuPad : 0
        height: submenuProgress > 0 ? submenuSurface.height : 0
    }

    NumberAnimation {
        id: submenuAnimation
        target: root
        property: "submenuProgress"
        to: root.submenuAnimationTarget
        duration: Lazer.MotionTokens.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Lazer.MotionTokens.outSoft
        onFinished: {
            if (submenuProgress === 0) {
                submenuEntry = null
                submenuAnchorRow = null
                submenuPhase = "closed"
                dismissingForLeaf = false
            } else if (submenuProgress === 1) {
                submenuPhase = "open"
                root.resolveSubHoverFromMemory()
            }
        }
    }
}
