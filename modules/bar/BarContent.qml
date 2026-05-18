import "."
import "../../services" as Services
import QtQuick

// Compose the left, center, and right bar zones with drag overlay.
Item {
    id: root

    required property string screenName

    // Keep the transparent container tall enough for unified side bottom ears.
    implicitHeight: Math.max(
        Services.BarLayoutService.barHeight,
        leftSection.implicitHeight,
        centerSection.implicitHeight,
        rightSection.implicitHeight
    )

    // Report section pixel bounds to the service for drag hit-testing.
    function _updateSectionBounds() {
        Services.BarLayoutService.sectionBounds = [
            { name: "left", left: leftSection.x, right: leftSection.x + leftSection.width },
            { name: "center", left: centerSection.x, right: centerSection.x + centerSection.width },
            { name: "right", left: rightSection.x, right: rightSection.x + rightSection.width }
        ]
    }

    // Report widget center positions per section for drag insertion calculation.
    function _updateWidgetCenters() {
        var centers = { left: [], center: [], right: [] }
        _collectCenters(leftSection, "left", centers)
        _collectCenters(centerSection, "center", centers)
        _collectCenters(rightSection, "right", centers)
        Services.BarLayoutService.widgetCentersBySection = centers
    }

    function _collectCenters(section, sectionName, centers) {
        var model = Services.BarLayoutService.sectionWidgets(sectionName)
        // Approximate centers from section x + cumulative widths
        var offset = section.x
        for (var i = 0; i < model.length; i++) {
            var w = model[i].implicitWidth || 40
            centers[sectionName].push({
                instanceKey: model[i].instanceKey || "",
                centerX: offset + w / 2
            })
            offset += w
        }
    }

    // Keep the left zone anchored to the screen edge.
    BarSection {
        id: leftSection

        sectionName: "left"
        screenName: root.screenName
        anchors.left: parent.left
        anchors.top: parent.top
        onWidthChanged: root._updateSectionBounds()
        onXChanged: root._updateSectionBounds()
    }

    // Keep the center zone aligned to the screen midpoint.
    // Hidden: island module now owns center content.
    BarSection {
        id: centerSection

        sectionName: "center"
        screenName: root.screenName
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        visible: false
        onWidthChanged: root._updateSectionBounds()
        onXChanged: root._updateSectionBounds()
    }

    // Keep the right zone anchored to the screen edge.
    BarSection {
        id: rightSection

        sectionName: "right"
        screenName: root.screenName
        anchors.right: parent.right
        anchors.top: parent.top
        onWidthChanged: root._updateSectionBounds()
        onXChanged: root._updateSectionBounds()
    }

    // Drag insertion indicator overlay.
    DragOverlay {
    }

    // Open context menu on widget right-click (called from BarWidgetWrapper).
    function openWidgetContextMenu(instanceKey, widgetId, clickX) {
        Services.BarLayoutService.openContextMenu(clickX, instanceKey, widgetId)
    }

    // Right-click on empty bar area opens the context menu.
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: (mouse) => Services.BarLayoutService.openContextMenu(mouse.x, "", "")
    }

    // Escape key exits settings mode and closes context menu.
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: Services.BarLayoutService.settingsMode || Services.BarLayoutService.contextMenuVisible
        onActivated: {
            Services.BarLayoutService.closeContextMenu()
            Services.BarLayoutService.exitSettingsMode()
        }
    }

    Component.onCompleted: {
        _updateSectionBounds()
        _updateWidgetCenters()
    }

    onWidthChanged: {
        _updateSectionBounds()
        _updateWidgetCenters()
    }

}
