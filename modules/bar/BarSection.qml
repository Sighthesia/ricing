import "."
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import QtQuick

// Render a single ordered section inside a shared attached-island surface.
Item {
    id: root

    required property string sectionName
    required property string screenName
    readonly property var sectionModel: Services.BarLayoutService.sectionWidgets(sectionName)

    implicitHeight: Services.BarLayoutService.barHeight
    implicitWidth: sectionSurface.implicitWidth
    width: implicitWidth
    height: implicitHeight

    // Inspector registration state for this section.
    property string inspectorId: ""
    readonly property bool isInspectorTarget: inspectorId !== "" &&
        Services.InspectorService.enabled &&
        ((Services.InspectorService.hoveredTarget && Services.InspectorService.hoveredTarget.id === inspectorId) ||
         (Services.InspectorService.lockedTarget && Services.InspectorService.lockedTarget.id === inspectorId))
    readonly property bool isInspectorHovered: inspectorId !== "" &&
        Services.InspectorService.enabled &&
        Services.InspectorService.hoveredTarget &&
        Services.InspectorService.hoveredTarget.id === inspectorId
    readonly property bool isInspectorLocked: inspectorId !== "" &&
        Services.InspectorService.enabled &&
        Services.InspectorService.lockedTarget &&
        Services.InspectorService.lockedTarget.id === inspectorId

    // Register this section with the inspector service on creation.
    Component.onCompleted: {
        inspectorId = Services.InspectorService.registerTarget(
            "BarSection", sectionName, sectionName, root.screenName,
            mapToItem(null, 0, 0).x, mapToItem(null, 0, 0).y,
            width, height
        )
    }
    Component.onDestruction: {
        if (inspectorId) Services.InspectorService.unregisterTarget(inspectorId)
    }

    // Refresh inspector geometry when size or position changes.
    onWidthChanged: _syncInspectorGeometry()
    onHeightChanged: _syncInspectorGeometry()
    onXChanged: _syncInspectorGeometry()
    onYChanged: _syncInspectorGeometry()

    function _syncInspectorGeometry() {
        if (!inspectorId) return
        Services.InspectorService.updateTargetGeometry(
            inspectorId,
            mapToItem(null, 0, 0).x, mapToItem(null, 0, 0).y,
            width, height
        )
    }

    // Highlight outline drawn when this section is inspected.
    Rectangle {
        anchors.fill: parent
        visible: root.isInspectorTarget
        color: "transparent"
        border.color: root.isInspectorLocked ? "#ff8844" : "#4488ff"
        border.width: 2
        z: 100
    }

    // Transparent hover surface that intercepts pointer events only in inspector mode.
    MouseArea {
        anchors.fill: parent
        enabled: Services.InspectorService.enabled
        hoverEnabled: true
        z: 101
        propagateComposedEvents: true
        onEntered: Services.InspectorService.setHovered(root.inspectorId)
        onExited: Services.InspectorService.clearHovered(root.inspectorId)
        onClicked: function(mouse) {
            Services.InspectorService.selectTarget(root.inspectorId)
            mouse.accepted = false
        }
    }

    // Wrap the ordered widgets in the shared section background.
    BarDockZoneBackground {
        id: sectionSurface

        screenName: root.screenName
        sectionType: root.sectionName
        surfaceHeight: root.implicitHeight
        contentWidth: sectionRow.implicitWidth
        contentHeight: sectionRow.implicitHeight

        // Lay out widgets for this section in order.
        Row {
            id: sectionRow

            x: sectionSurface.bodyX + (sectionSurface.bodyWidth - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: BarLayoutSections.widgetSpacing

            // Instantiate each managed widget in sequence.
            Repeater {
                model: root.sectionModel.length

                // Keep each widget wrapper as the delegate so its implicit size drives the row.
                BarWidgetWrapper {
                    required property int index

                    screenName: root.screenName
                    widgetEntry: root.sectionModel[index]
                    widgetSource: Qt.resolvedUrl(widgetEntry.source)
                }

            }

        }

    }

}
