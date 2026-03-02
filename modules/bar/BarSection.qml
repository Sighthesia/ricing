import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

Item {
    id: section

    required property string role
    property var widgetRegistry: ({})

    implicitWidth: sectionRow.implicitWidth
    implicitHeight: parent ? parent.height : 0

    // Helper: filter layoutModel entries for this section + alignment
    function widgetsFor(alignment) {
        let result = [];
        for (let i = 0; i < BarLayoutService.layoutModel.count; i++) {
            let item = BarLayoutService.layoutModel.get(i);
            if (item.section === section.role && item.alignment === alignment && item.enabled) {
                result.push({ widgetId: item.id, order: item.order, index: i });
            }
        }
        result.sort((a, b) => a.order - b.order);
        return result;
    }

    // Rebuild widget list when layoutModel changes
    property var leftWidgets: []
    property var centerWidgets: []
    property var rightWidgets: []

    function rebuildWidgets() {
        leftWidgets = widgetsFor("left");
        centerWidgets = widgetsFor("center");
        rightWidgets = widgetsFor("right");
    }

    Component.onCompleted: rebuildWidgets()

    Connections {
        target: BarLayoutService.layoutModel
        function onCountChanged() { section.rebuildWidgets(); }
    }

    // Recalculate when layoutModel properties change
    Connections {
        target: BarLayoutService
        function onSettingsModeChanged() { section.rebuildWidgets(); }
    }

    RowLayout {
        id: sectionRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Align-left sub-row
        Row {
            id: alignLeftRow
            spacing: 6
            Repeater {
                model: section.leftWidgets
                delegate: widgetDelegate
            }
        }

        // Align-center sub-row
        Row {
            id: alignCenterRow
            spacing: 6
            Repeater {
                model: section.centerWidgets
                delegate: widgetDelegate
            }
        }

        // Align-right sub-row
        Row {
            id: alignRightRow
            spacing: 6
            Repeater {
                model: section.rightWidgets
                delegate: widgetDelegate
            }
        }
    }

    // Shared delegate: BarWidgetWrapper + Loader
    Component {
        id: widgetDelegate

        BarWidgetWrapper {
            required property var modelData
            staggerIndex: modelData.index
            widgetId: modelData.widgetId

            Loader {
                source: section.widgetRegistry[modelData.widgetId] || ""
                active: source !== ""
            }
        }
    }
}
