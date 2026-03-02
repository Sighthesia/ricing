pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property bool settingsMode: false
    property ListModel layoutModel: ListModel {}

    // Default layout descriptor (from bar-design.md §三)
    readonly property var defaultLayout: [
        { id: "settingsToggle", section: "left",   alignment: "left",   order: 0, enabled: true },
        { id: "clock",          section: "center", alignment: "center", order: 0, enabled: true }
    ]

    Component.onCompleted: resetLayout()

    function moveWidget(widgetId, toSection, toAlignment, toOrder) {
        for (let i = 0; i < layoutModel.count; i++) {
            if (layoutModel.get(i).id === widgetId) {
                layoutModel.setProperty(i, "section", toSection);
                layoutModel.setProperty(i, "alignment", toAlignment);
                layoutModel.setProperty(i, "order", toOrder);
                break;
            }
        }
        // FIXME: persist to PersistentProperties
    }

    function resetLayout() {
        layoutModel.clear();
        for (let i = 0; i < defaultLayout.length; i++) {
            layoutModel.append(defaultLayout[i]);
        }
    }
}
