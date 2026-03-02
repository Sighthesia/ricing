import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

Item {
    id: barContent

    // Widget registry: maps widget ID to QML source path
    readonly property var widgetRegistry: ({
        "settingsToggle": "widgets/SettingsToggle.qml",
        "clock":          "widgets/Clock.qml",
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.barPadding
        anchors.rightMargin: Theme.barPadding
        spacing: 0

        BarSection {
            role: "left"
            widgetRegistry: barContent.widgetRegistry
            Layout.fillHeight: true
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        BarSection {
            role: "center"
            widgetRegistry: barContent.widgetRegistry
            Layout.fillHeight: true
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }

        BarSection {
            role: "right"
            widgetRegistry: barContent.widgetRegistry
            Layout.fillHeight: true
        }
    }

    // Settings mode drag overlay (z:999)
    DragOverlay {
        anchors.fill: parent
    }
}
