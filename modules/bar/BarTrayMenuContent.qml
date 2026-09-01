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
    implicitHeight: Math.max(heldHeight, emptyStateVisible ? 32 : menuFlick.height)

    property var menuHandle: null
    property bool useStubEntries: false
    readonly property int liveCount: rootOpenerLoader.item ? rootOpenerLoader.item.count : 0
    readonly property var liveValues: rootOpenerLoader.item ? rootOpenerLoader.item.values : []
    property var entries: null
    readonly property bool stubEntriesActive: useStubEntries
        || (entries !== null && entries !== undefined && Logic.entryList(entries).length > 0)
    readonly property var entryModel: stubEntriesActive
        ? Logic.entryList(entries)
        : Logic.entryList(liveValues)
    readonly property bool menuLoading: menuHandle != null && !stubEntriesActive
        && liveCount === 0 && rootOpenerLoader.status !== Loader.Error
    readonly property bool emptyStateVisible: menuHandle === null
        || (stubEntriesActive ? rowCount === 0 : (liveCount === 0 && !menuLoading))
    readonly property int rowCount: stubEntriesActive ? Logic.entryList(entries).length : liveCount

    property string submenuPhase: "closed"
    property real submenuProgress: 0
    property var submenuEntry: null
    property Item submenuAnchorRow: null
    property int submenuAnchorLevel: submenuAnchorRow ? submenuAnchorRow.level : 0
    property var submenuEntries: []
    property real heldHeight: 0
    property real rawColumnHeight: menuColumn.implicitHeight
    property real submenuAnimationTarget: 0
    property bool popsRight: true
    readonly property real enterTravel: 4 + width * Lazer.MotionTokens.popupFromScale + 4
    readonly property real extraWidth: submenuProgress > 0 ? submenuSurface.width + 4 : 0
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
        submenuEntry = entry
        if (row)
            submenuAnchorRow = row
        submenuAnimation.duration = Lazer.MotionTokens.reducedMotion ? 0 : Lazer.MotionTokens.medium
        submenuAnimation.easing.type = Easing.BezierSpline
        submenuAnimation.easing.bezierCurve = Lazer.MotionTokens.outSoft
        submenuAnimationTarget = 1
        if (Lazer.MotionTokens.reducedMotion) {
            submenuProgress = 1
            submenuPhase = "open"
            submenuAnimation.restart()
            return
        }
        if (submenuPhase !== "opening" && submenuPhase !== "open")
            submenuPhase = "opening"
        submenuAnimation.restart()
    }

    function closeSubmenu() {
        if (submenuEntry === null && submenuProgress === 0)
            return
        submenuAnimation.duration = Lazer.MotionTokens.reducedMotion ? 0 : Lazer.MotionTokens.slow
        submenuAnimation.easing.type = Easing.BezierSpline
        submenuAnimation.easing.bezierCurve = Lazer.MotionTokens.inOut
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

    // Native DBus menus only populate after QsMenuOpener is attached.
    Loader {
        id: rootOpenerLoader
        active: !root.stubEntriesActive && root.menuHandle != null
        source: "QsMenuOpenerBridge.qml"
        onLoaded: if (item) item.menu = root.menuHandle
    }

    Binding {
        target: rootOpenerLoader.item
        property: "menu"
        value: root.menuHandle
        when: rootOpenerLoader.item != null
    }

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

    // Opaque root face hides the scaled submenu until it has slid clear.
    Rectangle {
        id: menuFace
        objectName: "trayMenuFace"
        z: 2
        width: parent.width
        height: menuFlick.height
        color: "#24242d"
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

        // Root-level entries are kept in a compact, scan-friendly column.
        Column {
            id: menuColumn
            objectName: "trayMenuColumn"
            width: menuFlick.width
            spacing: 4

            Repeater {
                model: stubEntriesActive ? entryModel : liveValues

                delegate: Item {
                    id: rootRow
                    required property var modelData
                    property int level: 1
                    width: menuColumn.width
                    height: Logic.isSeparator(modelData) ? 9 : 32
                    objectName: Logic.isSeparator(modelData) ? "trayMenuSeparator" : "trayMenuRow"

                    Rectangle {
                        visible: Logic.isSeparator(modelData)
                        width: parent.width - 24
                        height: 1
                        x: 12
                        y: 4
                        color: "#4b4b57"
                    }

                    // Interactive root menu row.
                    Rectangle {
                    id: rowSurface
                    objectName: "trayMenuRowSurface"
                    visible: !Logic.isSeparator(modelData)
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

    // Preserve the second-level surface during its closing transition.
    Rectangle {
        id: submenuSurface
        objectName: "traySubmenuSurface"
        z: 1
        opacity: 1
        visible: submenuProgress > 0
        width: parent.width
        height: Math.max(32, submenuColumn.implicitHeight)
        x: parent.width + 4
        y: submenuAnchorRow ? submenuAnchorRow.y : 0
        color: "#24242d"

        Text {
            objectName: "traySubmenuTitle"
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 8
            text: Logic.submenuTitle(submenuEntry)
            color: "#eeeeF2"
            font.pixelSize: 13
        }

        // Child entries remain held during closing and update from the live opener.
        Column {
            id: submenuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 32
            spacing: 4
            Repeater {
                model: root.stubEntriesActive ? Logic.entryList(root.submenuEntries)
                    : (submenuOpenerLoader.item ? submenuOpenerLoader.item.values : [])
                delegate: Item {
                    required property var modelData
                    property int level: 2
                    width: submenuColumn.width
                    height: Logic.isSeparator(modelData) ? 9 : 32
                    objectName: Logic.isSeparator(modelData) ? "traySubmenuSeparator" : "trayMenuRow"

                    Rectangle {
                        visible: Logic.isSeparator(modelData)
                        width: parent.width - 24
                        height: 1
                        x: 12
                        y: 4
                        color: "#4b4b57"
                    }
                    Rectangle {
                        objectName: "trayMenuRowSurface"
                        visible: !Logic.isSeparator(modelData)
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

        transform: [
            Scale {
                origin.x: 0
                origin.y: 0
                xScale: Lazer.MotionTokens.popupFromScale
                yScale: Lazer.MotionTokens.popupFromScale
            },
            Translate {
                x: (root.popsRight ? 1 : -1) * root.enterTravel * (1 - root.submenuProgress)
            }
        ]
    }

    // Keep pointer traversal alive across the small root/submenu gap.
    Item {
        objectName: "traySubmenuBridge"
        z: 0
        x: parent.width
        y: submenuSurface.y
        width: submenuProgress > 0 ? 4 : 0
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
