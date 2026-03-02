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

    Connections {
        target: BarLayoutService
        function onLayoutChanged() { section.rebuildWidgets(); }
        function onSettingsModeChanged() { section.rebuildWidgets(); }
    }

    // Calculate which position a widget would insert at, given localX in section space
    // Skips the currently-dragged widget to avoid index flickering
    function insertIndexAt(localX) {
        let row = alignLeftRow;
        let dragId = BarLayoutService.draggedWidgetId;
        let slots = [];
        for (let i = 0; i < row.children.length; i++) {
            let child = row.children[i];
            if (!child || !child.visible) continue;
            if (child.widgetId && child.widgetId === dragId) continue;
            slots.push(child);
        }
        for (let i = 0; i < slots.length; i++) {
            let childCenter = slots[i].x + slots[i].width / 2;
            if (localX < childCenter) return i;
        }
        return slots.length;
    }

    // Expose the left Row for external position queries
    readonly property Item widgetRow: alignLeftRow

    RowLayout {
        id: sectionRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Align-left sub-row
        Row {
            id: alignLeftRow
            spacing: 6
            Repeater {
                id: leftRepeater
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

    // Insertion indicator line
    Rectangle {
        id: insertIndicator
        visible: BarLayoutService.isDragging
            && BarLayoutService.ghostSection === section.role
            && BarLayoutService.ghostIndex >= 0
        width: 2
        height: Theme.barHeight - 12
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.highlight
        radius: 1
        opacity: 0.8

        x: {
            if (!visible) return 0;
            let idx = BarLayoutService.ghostIndex;
            let row = alignLeftRow;
            let dragId = BarLayoutService.draggedWidgetId;
            // Build slots excluding the dragged widget
            let slots = [];
            for (let i = 0; i < row.children.length; i++) {
                let c = row.children[i];
                if (!c || !c.visible) continue;
                if (c.widgetId && c.widgetId === dragId) continue;
                slots.push(c);
            }
            if (idx >= slots.length) {
                let last = slots[slots.length - 1];
                return last ? (sectionRow.x + row.x + last.x + last.width + 3) : sectionRow.x;
            }
            let child = slots[idx];
            return child ? (sectionRow.x + row.x + child.x - 3) : sectionRow.x;
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
