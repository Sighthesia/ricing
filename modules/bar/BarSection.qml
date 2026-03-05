import QtQuick
import qs.config
import qs.services

Item {
    id: section

    required property string role
    property var widgetRegistry: ({})

    implicitWidth: widgetRow.implicitWidth
    implicitHeight: parent ? parent.height : 0

    Behavior on implicitWidth {
        enabled: BarLayoutService.settingsMode
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on x {
        enabled: BarLayoutService.settingsMode
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Collect enabled widgets for this section, sorted by order
    property var widgets: []

    function rebuildWidgets() {
        let result = [];
        for (let i = 0; i < BarLayoutService.layoutModel.count; i++) {
            let item = BarLayoutService.layoutModel.get(i);
            if (item.section === section.role && item.enabled)
                result.push({ widgetId: item.id, order: item.order, index: i });
        }
        // Use layoutModelIndex as stable key for Repeater
        result.sort((a, b) => a.order - b.order);
        widgets = result;
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

    /// Determine insertion index for a drag at `localX` in section space.
    /// Skips the currently-dragged widget and non-widget children (Repeater).
    function insertIndexAt(localX) {
        let dragId = BarLayoutService.draggedWidgetId;
        let slots = [];
        for (let i = 0; i < widgetRow.children.length; i++) {
            let child = widgetRow.children[i];
            if (!child || !child.visible) continue;
            if (!child.widgetId) continue;
            if (child.widgetId === dragId) continue;
            slots.push({ x: child.x, w: child.width });
        }
        for (let i = 0; i < slots.length; i++) {
            let center = slots[i].x + slots[i].w / 2;
            if (localX < center) return i;
        }
        return slots.length;
    }

    Row {
        id: widgetRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.widgetSpacing

        move: Transition {
            enabled: BarLayoutService.settingsMode || BarLayoutService.isDragging
            NumberAnimation {
                properties: "x,y"
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        add: Transition {
            enabled: BarLayoutService.settingsMode || BarLayoutService.isDragging
            NumberAnimation {
                property: "opacity"
                from: 0; to: 1.0
                duration: Theme.anim.moveDuration
            }
        }

        Repeater {
            model: section.widgets
            delegate: widgetDelegate
        }
    }

    // Active target highlight: shown when the widget picker is open and targeting this section
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Colors.highlight
        opacity: BarLayoutService.widgetPickerOpen
                 && BarLayoutService.widgetPickerTargetSection === section.role ? 0.08 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    // Insertion indicator line (visible during drag when hovering this section)
    Rectangle {
        id: insertIndicator
        visible: BarLayoutService.isDragging
            && BarLayoutService.ghostSection === section.role
            && BarLayoutService.ghostIndex >= 0
        width: 2
        height: Theme.barHeight - Theme.widgetPadding
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.highlight
        radius: 1
        opacity: 0.8

        Behavior on x {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        x: {
            if (!visible) return 0;
            let idx = BarLayoutService.ghostIndex;
            let dragId = BarLayoutService.draggedWidgetId;
            let slots = [];
            for (let i = 0; i < widgetRow.children.length; i++) {
                let c = widgetRow.children[i];
                if (!c || !c.visible) continue;
                if (!c.widgetId) continue;
                if (c.widgetId === dragId) continue;
                slots.push(c);
            }
            if (idx >= slots.length) {
                let last = slots[slots.length - 1];
                return last ? (widgetRow.x + last.x + last.width + 3) : 0;
            }
            let child = slots[idx];
            return child ? (widgetRow.x + child.x - 3) : 0;
        }
    }

    Component {
        id: widgetDelegate

        BarWidgetWrapper {
            required property var modelData
            staggerIndex: modelData.index
            widgetId: modelData.widgetId
            instanceKey: BarLayoutService.instanceKeyAt(modelData.index)

            Loader {
                source: section.widgetRegistry[modelData.widgetId] || ""
                active: source !== ""
            }
        }
    }
}
