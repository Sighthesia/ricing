pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property bool settingsMode: false
    property bool isDragging: false
    property string dragHoverZone: ""
    property string draggedWidgetId: ""
    // Floating copy position in BarContent coordinates
    property real dragVisualX: 0
    // Ghost insertion indicator: section + index + width
    property string ghostSection: ""
    property int ghostIndex: -1
    property real ghostWidth: 0
    property ListModel layoutModel: ListModel {}

    signal layoutChanged()

    // Default layout descriptor (from bar-design.md §三)
    readonly property var defaultLayout: [
        { id: "settingsToggle",  section: "left",   alignment: "left", order: 0, enabled: true },
        { id: "workspaceWidget", section: "left",   alignment: "left", order: 1, enabled: true },
        { id: "clock",           section: "center", alignment: "left", order: 0, enabled: true }
    ]

    Component.onCompleted: resetLayout()

    function moveWidget(widgetId, toSection, toAlignment, toOrder) {

        // Collect all widgets in target section (excluding the moving one)
        let others = [];
        let movingIdx = -1;
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (item.id === widgetId) {
                movingIdx = i;
                continue;
            }
            if (item.section === toSection) {
                others.push({ modelIndex: i, order: item.order });
            }
        }
        if (movingIdx < 0) return;

        // Sort by current order
        others.sort(function(a, b) { return a.order - b.order; });

        // Insert the moving widget at the desired position
        let insertAt = Math.min(toOrder, others.length);
        others.splice(insertAt, 0, { modelIndex: movingIdx, order: -1 });

        // Reassign sequential orders and update section/alignment
        for (let i = 0; i < others.length; i++) {
            let mi = others[i].modelIndex;
            layoutModel.setProperty(mi, "order", i);
            if (mi === movingIdx) {
                layoutModel.setProperty(mi, "section", toSection);
                layoutModel.setProperty(mi, "alignment", toAlignment);
            }
        }
        layoutChanged();
        // FIXME: persist to PersistentProperties
    }

    function resetLayout() {
        layoutModel.clear();
        for (let i = 0; i < defaultLayout.length; i++) {
            layoutModel.append(defaultLayout[i]);
        }
    }
}
