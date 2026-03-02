pragma Singleton

import Quickshell
import Quickshell.Io
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

    readonly property string _configDir: Quickshell.workingDirectory + "/.state"
    readonly property string _configFile: _configDir + "/layout.json"

    // Persist across hot reloads
    PersistentProperties {
        id: persist
        reloadableId: "barLayoutPersist"
        property string layoutJson: ""
    }

    Component.onCompleted: {
        // Try loading from hot-reload state first, then from disk
        if (persist.layoutJson !== "") {
            applyJson(persist.layoutJson);
        } else {
            fileReader.running = true;
        }
    }

    // Read saved layout from disk on startup
    Process {
        id: fileReader
        command: ["cat", root._configFile]
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed !== "") root.applyJson(trimmed);
            }
        }
        onRunningChanged: {
            // If file doesn't exist or cat fails, fall back to default
            if (!running && root.layoutModel.count === 0)
                root.resetLayout();
        }
    }

    // Write layout to disk (fire-and-forget)
    Process {
        id: fileWriter
        stdinEnabled: true
        command: ["sh", "-c", "mkdir -p '" + root._configDir + "' && cat > '" + root._configFile + "'"]
    }

    function serializeLayout() {
        let arr = [];
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            arr.push({
                id: item.id, section: item.section,
                alignment: item.alignment, order: item.order,
                enabled: item.enabled
            });
        }
        return JSON.stringify(arr);
    }

    function applyJson(json) {
        try {
            let arr = JSON.parse(json);
            if (!Array.isArray(arr) || arr.length === 0) {
                resetLayout();
                return;
            }
            layoutModel.clear();
            for (let i = 0; i < arr.length; i++)
                layoutModel.append(arr[i]);
            layoutChanged();
        } catch (e) {
            console.log("BarLayoutService: failed to parse layout JSON:", e);
            resetLayout();
        }
    }

    function saveLayout() {
        let json = serializeLayout();
        persist.layoutJson = json;
        // Write to disk
        fileWriter.running = false;
        fileWriter.running = true;
        fileWriter.write(json + "\n");
    }

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
        saveLayout();
    }

    function resetLayout() {
        layoutModel.clear();
        for (let i = 0; i < defaultLayout.length; i++) {
            layoutModel.append(defaultLayout[i]);
        }
    }
}
