import QtQuick
import "../lazerbar"
import "./ShippedWidgets.js" as ShippedWidgets
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections

// Lay out the enabled widgets into the left, center, and right sections.
Item {
    id: root

    property string screenName: ""
    readonly property int sidePadding: 12

    // Widget loaders start one tick late so every service singleton is
    // fully registered before widget bindings evaluate.
    property bool widgetsReady: false

    // Filter a section's entries down to implemented widgets; the shipped
    // set lives in the shared ShippedWidgets source so it cannot drift
    // between production and tests.
    function loadableWidgets(sectionName) {
        return ShippedWidgets.loadable(Services.BarLayoutService.sectionWidgets(sectionName))
    }

    // Registry source paths are already relative to this file's directory.
    function widgetSourceUrl(source) {
        return Qt.resolvedUrl(String(source || ""))
    }

    // Pixel bounds of one section as a {left, width} pair; zero width while
    // geometry has not been published yet.
    function sectionBound(sectionName) {
        var bounds = Services.BarLayoutService.sectionBounds
        for (var index = 0; index < bounds.length; index++) {
            if (bounds[index].name === sectionName)
                return { left: bounds[index].left, width: bounds[index].right - bounds[index].left }
        }
        return { left: 0, width: 0 }
    }

    // X of the drop caret: midway between the neighbors framing the ghost
    // insertion slot, or the section middle when it holds no widgets.
    function dropCaretX() {
        var service = Services.BarLayoutService
        if (!service.isDragging || !service.ghostSection)
            return -10
        var bound = root.sectionBound(service.ghostSection)
        var centers = service.widgetCentersBySection[service.ghostSection] || []
        if (!centers.length)
            return bound.left + bound.width / 2 - dropCaret.width / 2
        var index = service.ghostIndex
        if (index <= 0)
            return centers[0].centerX - BarLayoutSections.widgetSpacing / 2 - dropCaret.width / 2
        if (index >= centers.length)
            return centers[centers.length - 1].centerX + BarLayoutSections.widgetSpacing / 2
                    - dropCaret.width / 2
        return (centers[index - 1].centerX + centers[index].centerX) / 2 - dropCaret.width / 2
    }

    // Hit-test the section rows for the loader under a bar-local point.
    function widgetAt(x, y) {
        var rows = [
            { row: leftRow },
            { row: centerRow },
            { row: rightRow },
        ]

        for (var index = 0; index < rows.length; index++) {
            var row = rows[index].row
            for (var childIndex = 0; childIndex < row.children.length; childIndex++) {
                var loader = row.children[childIndex]
                if (!loader || !loader.item)
                    continue
                var pos = loader.mapToItem(root, 0, 0)
                if (x >= pos.x && x <= pos.x + loader.width
                        && y >= pos.y && y <= pos.y + loader.height) {
                    return {
                        instanceKey: loader.item.instanceKey || "",
                        widgetId: loader.item.widgetId || "",
                        centerX: pos.x + loader.width / 2,
                    }
                }
            }
        }

        return null
    }

    // Publish section bounds and widget centers for the layout service.
    function publishGeometry() {
        var bounds = []
        var centersBySection = {}
        var sections = [
            { name: "left", row: leftRow },
            { name: "center", row: centerRow },
            { name: "right", row: rightRow },
        ]

        for (var index = 0; index < sections.length; index++) {
            var entry = sections[index]
            var row = entry.row
            bounds.push({ name: entry.name, left: row.x, right: row.x + row.width })

            var centers = []
            for (var childIndex = 0; childIndex < row.children.length; childIndex++) {
                var loader = row.children[childIndex]
                if (!loader || !loader.item)
                    continue
                centers.push({
                    instanceKey: loader.item.instanceKey || "",
                    centerX: row.x + loader.x + loader.width / 2,
                })
            }
            centersBySection[entry.name] = centers
        }

        Services.BarLayoutService.sectionBounds = bounds
        Services.BarLayoutService.widgetCentersBySection = centersBySection
    }

    function schedulePublish() {
        Qt.callLater(publishGeometry)
    }

    Component.onCompleted: {
        // One full tick so lazily registered service singletons exist
        // before any widget binding evaluates.
        Qt.callLater(function () {
            widgetsReady = true
            schedulePublish()
        })
    }

    Connections {
        target: Services.BarLayoutService
        function onLayoutModelChanged() { root.schedulePublish() }
    }

    component SectionRow: Row {
        id: sectionRow

        property string section

        spacing: BarLayoutSections.widgetSpacing
        anchors.verticalCenter: parent.verticalCenter
        onWidthChanged: root.schedulePublish()

        Repeater {
            model: root.loadableWidgets(sectionRow.section)

            // Instantiate each registry entry and hand it its identity props.
            delegate: Loader {
                id: widgetLoader

                required property var modelData

                active: root.widgetsReady
                source: modelData && modelData.source
                        ? root.widgetSourceUrl(modelData.source) : ""

                onLoaded: {
                    if (!item)
                        return
                    item.widgetId = modelData.id
                    item.instanceKey = modelData.instanceKey || ""
                    item.section = sectionRow.section
                    item.screenName = root.screenName
                }

                // The dragged widget recedes so the caret carries the intent.
                opacity: Services.BarLayoutService.draggedInstanceKey === modelData.instanceKey
                         ? 0.3 : 1
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }
        }
    }

    // Left section hugs the leading edge of the bar.
    SectionRow {
        id: leftRow
        section: "left"
        anchors.left: parent.left
        anchors.leftMargin: root.sidePadding
    }

    // Center section stays balanced regardless of side section widths.
    SectionRow {
        id: centerRow
        section: "center"
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // Right section trails the trailing edge of the bar.
    SectionRow {
        id: rightRow
        section: "right"
        anchors.right: parent.right
        anchors.rightMargin: root.sidePadding
    }

    // Dockzone outlines: reveal each section frame while arranging widgets.
    Repeater {
        model: ["left", "center", "right"]

        delegate: Rectangle {
            required property string modelData

            readonly property var bound: root.sectionBound(modelData)

            x: bound.left - 6
            y: 4
            width: bound.width + 12
            height: parent.height - 8
            radius: 0
            color: "transparent"
            border.width: 1
            border.color: LazerTheme.divider
            visible: opacity > 0 && width > 12
            opacity: Services.BarLayoutService.settingsMode ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }
    }

    // Drop caret: sharp accent strip marking the slot a dragged widget
    // will occupy; follows the ghost section/index from the layout service.
    Rectangle {
        id: dropCaret

        visible: Services.BarLayoutService.isDragging
        x: root.dropCaretX()
        y: 6
        width: 3
        height: parent.height - 12
        radius: 0
        color: LazerTheme.osuGreen
    }

    // Layout-mode drag surface: grabs left-button presses over any widget
    // and feeds the pointer's bar-local X to the layout drag state machine.
    MouseArea {
        anchors.fill: parent
        z: 50
        enabled: Services.BarLayoutService.settingsMode
        visible: Services.BarLayoutService.settingsMode
        acceptedButtons: Qt.LeftButton
        cursorShape: Services.BarLayoutService.settingsMode ? Qt.DragMoveCursor : Qt.ArrowCursor

        onPressed: mouse => {
            var hit = root.widgetAt(mouse.x, mouse.y)
            if (!hit)
                return
            Services.BarLayoutService.beginDrag(hit.instanceKey, hit.widgetId, mouse.x)
        }
        onPositionChanged: mouse => Services.BarLayoutService.updateDrag(mouse.x)
        onReleased: Services.BarLayoutService.endDrag()
        onCanceled: Services.BarLayoutService.cancelDrag()
    }


}
