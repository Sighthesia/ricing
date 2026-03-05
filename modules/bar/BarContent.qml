import QtQuick
import qs.config
import qs.services

Item {
    id: barContent

    // Widget registry: maps widget ID to QML source path
    readonly property var widgetRegistry: ({
        "clock":              "widgets/Clock.qml",
        "workspaceWidget":    "widgets/WorkspaceWidget.qml",
        "notificationBell":   "widgets/NotificationBell.qml"
    })

    // Hit-test: map x in barContent coords to section name (accounts for padding)
    function hitTestSection(localX) {
        let pad = Theme.barPadding;
        let w = barContent.width - 2 * pad;
        let x = localX - pad;
        if (x < w / 3) return "left";
        if (x < w * 2 / 3) return "center";
        return "right";
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
        "clock":              "时钟",
        "workspaceWidget":    "工作区",
        "notificationBell":   "通知"
    })

    // Left section: anchored left
    BarSection {
        id: leftSection
        role: "left"
        widgetRegistry: barContent.widgetRegistry
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
    }

    // Center section: anchored center
    BarSection {
        id: centerSection
        role: "center"
        widgetRegistry: barContent.widgetRegistry
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
    }

    // Right section: anchored right
    BarSection {
        id: rightSection
        role: "right"
        widgetRegistry: barContent.widgetRegistry
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
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
                let section = barContent.hitTestSection(mouse.x);
                if (BarLayoutService.widgetPickerOpen
                        && BarLayoutService.widgetPickerTargetSection === section) {
                    BarLayoutService.widgetPickerOpen = false;
                } else {
                    BarLayoutService.widgetPickerTargetSection = section;
                    BarLayoutService.widgetPickerOpen = true;
                }
            }
        }
    }

    // Global Esc: close any active panel, the context menu, and the widget picker.
    Shortcut {
        sequence: "Escape"
        enabled: BarLayoutService.activePanel !== "none" || contextMenu.visible || BarLayoutService.widgetPickerOpen
        onActivated: {
            BarLayoutService.activePanel = "none";
            BarLayoutService.contextMenuOpen = false;
            BarLayoutService.widgetPickerOpen = false;
        }
    }
}
