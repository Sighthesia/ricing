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
    readonly property bool menuLoading: resolvedMenuHandle != null && !stubEntriesActive
        && liveCount === 0
    readonly property bool emptyStateVisible: resolvedMenuHandle === null
        || (stubEntriesActive ? rowCount === 0 : (liveCount === 0 && !menuLoading))
    readonly property int rowCount: stubEntriesActive ? Logic.entryList(entries).length : liveCount

    property string submenuPhase: "closed"
    property real submenuProgress: 0
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

    function handleRowHover(level, rowHasChildren) {
        if (Logic.shouldCloseSubmenuOnRow(level, rowHasChildren))
            closeSubmenu()
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
        if (submenuEntry === null && submenuProgress === 0)
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
        color: "#b8b8c8"
        font.pixelSize: 13
        anchors.left: parent.left
        anchors.margins: 16
        anchors.verticalCenter: parent.verticalCenter
    }

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

            Repeater {
                model: root.menuSections

                delegate: Rectangle {
                    required property var modelData
                    objectName: "trayMenuSection"
                    width: menuColumn.width
                    height: sectionColumn.implicitHeight
                    color: Lazer.LazerTheme.settingsPanel

                    Column {
                        id: sectionColumn
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

                                // Interactive root menu row.
                                Rectangle {
                                id: rowSurface
                                objectName: "trayMenuRowSurface"
                                anchors.fill: parent
                                radius: 4
                                color: rowHover.hovered ? Lazer.LazerTheme.settingsCardHover : Lazer.LazerTheme.settingsCard
                                opacity: Logic.isEnabled(modelData) ? 1 : Lazer.MotionTokens.disabledOpacity

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        elide: Text.ElideRight
                        text: Logic.labelOf(modelData)
                        color: "#eeeeF2"
                        font.pixelSize: 13
                    }

                    Text {
                        visible: Logic.isChecked(modelData)
                        text: "✓"
                        anchors.right: parent.right
                        anchors.rightMargin: Logic.hasChildren(modelData) ? 30 : 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#8bd5ca"
                        font.pixelSize: 14
                    }

                    Text {
                        visible: Logic.hasChildren(modelData)
                        text: ">"
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#b8b8c8"
                        font.pixelSize: 14
                    }

                    Rectangle {
                        id: clickFlash
                        anchors.fill: parent
                        radius: parent.radius
                        color: "#ffffff"
                        opacity: 0
                    }

                    HoverHandler {
                        id: rowHover
                        onHoveredChanged: {
                            if (!hovered)
                                return
                            handleRowHover(level, Logic.hasChildren(modelData))
                            if (Logic.shouldOpenSubmenu(modelData))
                                openSubmenu(modelData, rootRow)
                        }
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
                color: "#eeeeF2"
                font.pixelSize: 13
                font.bold: true
            }
        }

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
                Repeater {
                    model: root.submenuSections
                    delegate: Rectangle {
                        required property var modelData
                        objectName: "traySubmenuSection"
                        width: submenuColumn.width
                        height: submenuSectionColumn.implicitHeight
                        color: Lazer.LazerTheme.settingsPanel
                        Column {
                            id: submenuSectionColumn
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: modelData
                                delegate: Item {
                                    required property var modelData
                                    property int level: 2
                                    width: submenuSectionColumn.width
                                    height: 32
                                    objectName: "trayMenuRow"
                                    Rectangle {
                                        objectName: "trayMenuRowSurface"
                                        anchors.fill: parent
                                        radius: 4
                                        color: submenuRowHover.hovered ? Lazer.LazerTheme.settingsCardHover : Lazer.LazerTheme.settingsCard
                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Logic.labelOf(modelData)
                                            color: "#eeeeF2"
                                            font.pixelSize: 13
                                        }
                                        HoverHandler { id: submenuRowHover }
                                        TapHandler { onTapped: activateEntry(modelData, 2) }
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
            }
        }
    }
}
