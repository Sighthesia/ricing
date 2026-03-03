import QtQuick
import qs.config

Item {
    id: barContent

    // Widget registry: maps widget ID to QML source path
    readonly property var widgetRegistry: ({
        "clock":           "widgets/Clock.qml",
        "workspaceWidget": "widgets/WorkspaceWidget.qml"
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
}
