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
}
