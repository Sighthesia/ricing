import "."
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import QtQuick

// Compose the left, center, and right bar zones with drag overlay.
Item {
    id: root

    required property string screenName
    readonly property var leftSectionBlurParts: leftSection.blurParts
    readonly property var rightSectionBlurParts: rightSection.blurParts
    readonly property real centerSurfaceWidth: Math.max(
        Services.IslandService.centerSurfaceWidthFor(root.screenName),
        Services.WindowHintService.centerSurfaceWidthFor(root.screenName)
    )
    readonly property real centerSurfaceLeft: root.width > 0 ? (root.width - root.centerSurfaceWidth) / 2 : 0
    readonly property real leftSectionPush: root.centerSurfaceWidth > 0
        ? Math.max(0, leftSection.width - root.centerSurfaceLeft)
        : 0
    readonly property real rightSectionPush: root.centerSurfaceWidth > 0
        ? Math.max(0, (root.centerSurfaceLeft + root.centerSurfaceWidth) - (root.width - rightSection.width))
        : 0
    property real leftSectionPushVisual: 0
    property real rightSectionPushVisual: 0
    property bool leftSectionReturnSpringEnabled: false
    property bool rightSectionReturnSpringEnabled: false

    // Keep the displayed push snapped to the target while expanding, and only
    // animate the return path once the center stops overlapping.
    Behavior on leftSectionPushVisual {
        enabled: root.leftSectionReturnSpringEnabled
        SpringAnimation {
            spring: Services.Motion.islandExpand.spring
            mass: Services.Motion.islandExpand.mass
            damping: Services.Motion.islandExpand.dampingCollapse
            epsilon: Services.Motion.islandExpand.epsilon
        }
    }

    // Same delayed-return spring for the right side.
    Behavior on rightSectionPushVisual {
        enabled: root.rightSectionReturnSpringEnabled
        SpringAnimation {
            spring: Services.Motion.islandExpand.spring
            mass: Services.Motion.islandExpand.mass
            damping: Services.Motion.islandExpand.dampingCollapse
            epsilon: Services.Motion.islandExpand.epsilon
        }
    }

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
            { name: "left", left: leftSection.mapToItem(null, 0, 0).x, right: leftSection.mapToItem(null, leftSection.width, 0).x },
            { name: "center", left: centerSection.mapToItem(null, 0, 0).x, right: centerSection.mapToItem(null, centerSection.width, 0).x },
            { name: "right", left: rightSection.mapToItem(null, 0, 0).x, right: rightSection.mapToItem(null, rightSection.width, 0).x }
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
        var spacing = BarLayoutSections.widgetSpacing
        // Approximate centers from section x + cumulative widths
        var offset = section.mapToItem(null, 0, 0).x
        for (var i = 0; i < model.length; i++) {
            var w = model[i].implicitWidth || 40
            centers[sectionName].push({
                instanceKey: model[i].instanceKey || "",
                centerX: offset + w / 2
            })
            offset += w
            if (i < model.length - 1)
                offset += spacing
        }
    }

    function _syncLeftSectionPush() {
        if (root.leftSectionPush >= root.leftSectionPushVisual) {
            root.leftSectionReturnSpringEnabled = false
            root.leftSectionPushVisual = root.leftSectionPush
            return
        }

        root.leftSectionReturnSpringEnabled = true
        root.leftSectionPushVisual = root.leftSectionPush
    }

    function _syncRightSectionPush() {
        if (root.rightSectionPush >= root.rightSectionPushVisual) {
            root.rightSectionReturnSpringEnabled = false
            root.rightSectionPushVisual = root.rightSectionPush
            return
        }

        root.rightSectionReturnSpringEnabled = true
        root.rightSectionPushVisual = root.rightSectionPush
    }

    // Keep the left zone anchored to the screen edge.
    BarSection {
        id: leftSection

        sectionName: "left"
        screenName: root.screenName
        sectionPushOffsetX: root.leftSectionPushVisual
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: -leftSection.residualPushOffsetX
        onWidthChanged: root._updateSectionBounds()
        onXChanged: root._updateSectionBounds()
    }

    // Keep the center zone aligned to the screen midpoint.
    // Hidden: island module now owns center content (and the transient message band).
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
        sectionPushOffsetX: root.rightSectionPushVisual
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -rightSection.residualPushOffsetX
        onWidthChanged: root._updateSectionBounds()
        onXChanged: root._updateSectionBounds()
    }

    // Drag insertion indicator overlay.
    DragOverlay {
    }

    // Open context menu on widget right-click (called from BarWidgetWrapper).
    function openWidgetContextMenu(instanceKey, widgetId, clickX, screenName, widgetCenterX) {
        Services.BarLayoutService.openContextMenu(clickX, instanceKey, widgetId, screenName || root.screenName)
        Services.BarLayoutService.widgetSettingsX = widgetCenterX || clickX
    }

    // Right-click on empty bar area opens the context menu.
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: (mouse) => Services.BarLayoutService.openContextMenu(mouse.x, "", "", root.screenName)
    }

    // Escape key exits settings mode and closes context menu.
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: Services.BarLayoutService.settingsMode || Services.BarLayoutService.contextMenuVisible || Services.BarLayoutService.widgetSettingsVisible
        onActivated: {
            Services.BarLayoutService.closeContextMenu()
            Services.BarLayoutService.closeWidgetSettings()
            Services.BarLayoutService.exitSettingsMode()
        }
    }

    onWidthChanged: {
        _updateSectionBounds()
        _updateWidgetCenters()
    }

    onLeftSectionPushChanged: {
        _syncLeftSectionPush()
        _updateSectionBounds()
        _updateWidgetCenters()
    }

    onRightSectionPushChanged: {
        _syncRightSectionPush()
        _updateSectionBounds()
        _updateWidgetCenters()
    }

    Component.onCompleted: {
        leftSectionPushVisual = leftSectionPush
        rightSectionPushVisual = rightSectionPush
        _syncLeftSectionPush()
        _syncRightSectionPush()
        _updateSectionBounds()
        _updateWidgetCenters()
    }

}
