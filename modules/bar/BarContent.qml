import QtQuick
import qs.config
import qs.services

// Main bar composition root that wires sections, overlays, and shared menus.
Item {
    id: barContent

    readonly property real _layoutPadding: Theme.barPadding

    function _sectionGeometry(sectionName) {
        return BarLayoutService.sectionGeometry(sectionName)
    }

    function _updateBarMetrics() {
        BarLayoutService.setBarMetrics(barContent.width, barContent._layoutPadding)
    }

    // Widget registry: maps widget ID to QML source path
    readonly property var widgetRegistry: ({
        "superIsland":        "widgets/SuperIslandWidget.qml",
        "mediaControl":       "widgets/MediaControlWidget.qml",
        "clock":              "widgets/Clock.qml",
        "workspaceWidget":    "widgets/WorkspaceWidget.qml",
        "notificationBell":   "widgets/NotificationBell.qml",
        "superSystemMonitor": "widgets/SuperSystemMonitorWidget.qml",
        "systemTray":         "widgets/SystemTrayWidget.qml"
    })

    // Hit-test: map x in barContent coords to section name (accounts for padding)
    function hitTestSection(localX) {
        return BarLayoutService.sectionForBarX(localX)
    }

    // Called by BarWidgetWrapper on right-click. Forwards to the shared context menu
    // with widget-specific arguments for the conditional widget section.
    function openWidgetContextMenu(instanceKey, widgetId, clickX, widgetCenterX) {
        let label = widgetNames[widgetId] || widgetId;
        contextMenu.showAt(clickX, 0, instanceKey, widgetCenterX, label);
    }

    // Human-readable widget type names — mirrors WidgetPickerWindow.widgetNames.
    // FIXME: promote to a shared singleton to avoid duplication.
    readonly property var widgetNames: ({
        "superIsland":        "超级灵动岛",
        "mediaControl":       "媒体控制",
        "clock":              "时钟",
        "workspaceWidget":    "工作区",
        "notificationBell":   "通知",
        "superSystemMonitor": "系统监控",
        "systemTray":         "系统托盘"
    })

    // Left section: anchored left
    BarSection {
        id: leftSection
        role: "left"
        widgetRegistry: barContent.widgetRegistry
        x: barContent._sectionGeometry("left").left
        width: barContent._sectionGeometry("left").width
        anchors.verticalCenter: undefined
        anchors.top: parent.top
        height: Theme.barHeight
    }

    // Center section: anchored center
    BarSection {
        id: centerSection
        role: "center"
        widgetRegistry: barContent.widgetRegistry
        x: barContent._sectionGeometry("center").left
        width: barContent._sectionGeometry("center").width
        anchors.verticalCenter: undefined
        anchors.top: parent.top
        height: Theme.barHeight
    }

    // Right section: anchored right
    BarSection {
        id: rightSection
        role: "right"
        widgetRegistry: barContent.widgetRegistry
        x: barContent._sectionGeometry("right").left
        width: barContent._sectionGeometry("right").width
        anchors.verticalCenter: undefined
        anchors.top: parent.top
        height: Theme.barHeight
    }

    // Settings mode drag overlay (z:999)
    DragOverlay {
        anchors.fill: parent
        widgetRegistry: barContent.widgetRegistry
    }

    // Right-click context menu for the bar background.
    BarContextMenu {
        id: contextMenu
        anchorTarget: barContent
    }

    // Floating per-widget settings panel — shown when a widget is being configured.
    WidgetSettingsPanel {
        anchorTarget: barContent
    }

    // Transparent full-bar MouseArea at z:-1 — captures right-clicks on empty bar space.
    // In layout mode, left-clicks on blank bar area open the widget picker for that section.
    // z:-1 ensures widget MouseAreas (z:0) handle cursor shape and hover events first.
    // propagateComposedEvents: true so widgets still receive their own events.
    MouseArea {
        id: barRightClick
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton | Qt.LeftButton
        propagateComposedEvents: true
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.showAt(mouse.x, mouse.y);
            } else if (BarLayoutService.settingsMode) {
                // Left-click in layout mode: toggle picker for the clicked section.
                // Clicking the already-active section closes the picker.
                let section = barContent.hitTestSection(mouse.x)
                BarLayoutService.toggleWidgetPickerForSection(section)
            }
        }
    }

    // Global Esc: close any active panel, the context menu, and the widget picker.
    Shortcut {
        sequence: "Escape"
        enabled: BarLayoutService.activePanel !== "none"
            || contextMenu.visible
            || BarLayoutService.trayMenuOpen
            || BarLayoutService.widgetPickerOpen
        onActivated: {
            BarLayoutService.activePanel = "none";
            BarLayoutService.contextMenuOpen = false;
            BarLayoutService.trayMenuOpen = false;
            BarLayoutService.widgetPickerOpen = false;
        }
    }

    Component.onCompleted: _updateBarMetrics()

    onWidthChanged: _updateBarMetrics()
}
