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
}
