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
    implicitHeight: {
        if (emptyStateVisible) return 32
        if (menuLoading) return Math.max(heldHeight, 72)
        return Math.max(heldHeight, menuFlick.height)
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
    property real heldHeight: 420
    property real rawColumnHeight: menuColumn.implicitHeight
    property real submenuAnimationTarget: 0
    // Flip the second level to the left when the tray icon sits at the
    // screen edge: expanding right would shove the primary column left.
    property bool submenuFlipped: false
    property bool popsRight: true
    onSubmenuFlippedChanged: popsRight = !submenuFlipped
    // Submenu panel mirrors the primary panel: same button width, same 8
    // padding on the outer edges. The meeting edge butts flush against the
    // primary panel so paddings never stack into a band at the joint.
    readonly property real submenuPad: 8
    // Container growth covers the surface exactly: it butts flush against
    // the primary panel, so growth equals the surface width. (Travel spans
    // one pad more because the hidden position tucks the surface that pad
    // deeper under the face.)
    readonly property real extraWidth: submenuProgress > 0 ? submenuSurface.width : 0
    readonly property alias submenuSurface: submenuSurface
    readonly property alias submenuAnimation: submenuAnimation
    readonly property alias menuFace: menuFace
    readonly property real maxMenuHeight: Screen.desktopAvailableHeight > 0
        ? Math.max(180, Screen.desktopAvailableHeight * 0.7) : 420
    signal dismissRequested()

    function activateEntry(entry, level) {
        if (!Logic.isEnabled(entry))
            return
        if (Logic.shouldOpenSubmenu(entry)) {
            openSubmenu(entry, null)
            return
        }
        try {
            if (typeof entry.triggered === "function")
                entry.triggered()
        } catch (err) {}
        if (Logic.shouldDismissOnTrigger(entry))
            dismissRequested()
    }

    function openSubmenu(entry, row) {
        if (!Logic.shouldOpenSubmenu(entry))
            return
        // Redirect without replaying reveal when already visible.
        if ((submenuPhase === "open" || submenuPhase === "opening") && submenuEntry === entry) {
            if (row)
                submenuAnchorRow = row
            return
        }
        if (submenuPhase === "open" || submenuPhase === "opening") {
            submenuEntry = entry
            if (row)
                submenuAnchorRow = row
            return
        }
        submenuEntry = entry
        if (row)
            submenuAnchorRow = row
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
        width: parent.width + root.submenuPad * 2
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
        onEntered: { root.rememberCursor(mouseX, mouseY); root.hoverAtCatcher(mouseY + menuFlick.contentY) }
        onPositionChanged: { root.rememberCursor(mouseX, mouseY); root.hoverAtCatcher(mouseY + menuFlick.contentY) }
        onExited: root.hoverLeaveCatcher()
    }
    // Transit strip: the bridge zone toward the submenu, side-aware so the
    // outer margin never resurrects. Entering it while a submenu is
    // mid-retract bounces back open (slow arrivals killed just short);
    // otherwise it is a deliberate no-op.
    MouseArea {
        id: transitCatcher
        objectName: "traySubmenuTransitCatcher"
        x: root.submenuFlipped ? -root.submenuPad : menuFlick.width
        y: menuFlick.y
        width: root.submenuPad
        height: menuFlick.height
        z: 4
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: { root.rememberCursor(mouseX + transitCatcher.x, mouseY + transitCatcher.y); root.transitToSubmenu() }
        onExited: root.forgetCursor()
    }
    function transitToSubmenu() {
        if (submenuEntry && submenuPhase !== "open")
            openSubmenu(submenuEntry, submenuAnchorRow)
    }
    // Submenu hover state lives here at root level: functions nested inside
    // the surface are unreachable via root.* and fail silently.
    property Item highlightedSubmenuRow: null
        function hoverAtSubCatcher(contentY) {
            root.rememberCursor(subHoverCatcher.mouseX + submenuSurface.x,
                subHoverCatcher.mouseY + submenuSurface.y)
            highlightedSubmenuRow = rowAtContentY(submenuColumn, "traySubmenuSection", contentY).row
        }
    // Re-resolve under a stationary cursor from memory (root coords): the
    // reveal sliding under it and data rebuilds generate no hover events.
    // 12px tolerance toward the primary side covers arrivals parked on the
    // bridge strip.
    // Re-resolve under a stationary cursor from memory. Delegates may not
    // exist yet when this runs (model changes precede instantiation), so a
    // miss with no rows seen retries briefly; a miss with rows present is a
    // genuine gap and clears.
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
            highlightedSubmenuRow = null
            return
        }
        var m = rowAtContentY(submenuColumn, "traySubmenuSection", fy + submenuFlick.contentY)
        if (m.row) {
            highlightedSubmenuRow = m.row
            return
        }
        if (m.rowsSeen === 0 && retry < 5)
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
        highlightedRow = null
        forgetCursor()
    }
    // Primary rebuilds (cold batches) under a stationary cursor.
    onMenuSectionsChanged: resolveHoverFromMemory()

    // Root entries scroll inside the bounded visible menu surface.
    Flickable {
        id: menuFlick
        objectName: "trayMenuFlick"
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width
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
                            activateEntry(modelData, level)
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
    // Preserve the second-level surface during its closing transition.
    // Keep submenu the same bounded size as the primary flick so the
    // root list never shifts when the second level appears.
    Rectangle {
        id: submenuSurface
        objectName: "traySubmenuSurface"
        z: 1
        visible: submenuProgress > 0.01 && (hasSubmenuContent || submenuPhase === "closing")
        width: parent.width + root.submenuPad
        height: menuFlick.height
        x: submenuFlipped ? -(width + root.submenuPad) : parent.width + root.submenuPad
        y: 0
        color: Lazer.LazerTheme.settingsSection
        clip: true

        // Submenu title mirrors the popup identity header: full-width
        // settingsRail block, 48 high, bold 13px label on 12px margins.
        Rectangle {
            objectName: "traySubmenuTitleBlock"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 48
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

        // Submenu hover owner, mirroring the primary catcher: rows are pure
        // display, highlight follows the mapped row. Ungated by phase (hidden
        // rows paint under the opaque face anyway); taps stay gated.
        MouseArea {
            id: subHoverCatcher
            objectName: "traySubmenuHoverCatcher"
            anchors.fill: submenuFlick
            z: 4
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        onEntered: root.hoverAtSubCatcher(mouseY + submenuFlick.contentY)
        onPositionChanged: root.hoverAtSubCatcher(mouseY + submenuFlick.contentY)
        onExited: {
            root.highlightedSubmenuRow = null
            root.forgetCursor()
        }
    }
        // Cold batches rebuild delegates under a stationary cursor: recompute
        // from remembered position instead of losing the highlight. (Handled
        // at root level; a nested Connections here proved unreliable.)

        // Child entries remain held during closing and update from the live opener.
        Flickable {
            id: submenuFlick
            objectName: "traySubmenuFlick"
            // Padding lives only on the outer edge; the meeting edge is
            // flush so paddings never stack into a band at the joint.
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
        x: submenuFlipped ? -root.submenuPad : parent.width
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
            } else if (submenuProgress === 1) {
                submenuPhase = "open"
                root.resolveSubHoverFromMemory()
            }
        }
    }
}
