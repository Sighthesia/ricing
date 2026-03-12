pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Panel state: "none" | "layout" | "config"
    property string activePanel: "none"

    // True while the right-click context menu is open.
    // Used as a cross-window signal for the click-away backdrop.
    property bool contextMenuOpen: false

    // True while the widget picker panel is visible.
    property bool widgetPickerOpen: false

    // Which widget instance is currently being configured (instanceKey format: "{widgetId}_{n}").
    // Empty string means no widget is selected.
    property string activeWidgetInstanceKey: ""

    // Bar-coordinate X of the centre of the widget under configuration.
    // Used by WidgetSettingsPanel to position itself.
    property real widgetSettingsX: 0

    // True while the widget settings panel is visible.
    property bool widgetSettingsPanelOpen: false

    // True while the wallpaper picker overlay is visible.
    property bool wallpaperPickerOpen: false

    // True while the notification history panel is visible.
    property bool notificationHistoryOpen: false

    // Extra pixels the bar extends downward below exclusiveZone during widget flashes.
    property int workspaceFlashExtension: 0
    property int superIslandFlashExtension: 0
    property int mediaControlFlashExtension: 0
    readonly property int barFlashExtension:
        Math.max(workspaceFlashExtension, superIslandFlashExtension, mediaControlFlashExtension)

    // Which bar section the picker should insert widgets into.
    // Updated whenever the user clicks a section in layout mode.
    property string widgetPickerTargetSection: "right"

    // Left-edge pixel offset used by WidgetPickerWindow to position itself
    // below the active section. Updated together with widgetPickerTargetSection.
    property real widgetPickerLeftMargin: 0

    // Horizontal anchor position for the media control detail panel.
    property real mediaControlPanelX: 0

    // Computed alias — keeps all existing DragOverlay/BarSection bindings unchanged
    readonly property bool settingsMode: activePanel === "layout"

    onSettingsModeChanged: {
        if (!settingsMode) {
            widgetSettingsPanelOpen = false;
            activeWidgetInstanceKey = "";
        }
    }

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
        { id: "workspaceWidget", section: "left",   alignment: "left", order: 0, enabled: true },
        { id: "superIsland",     section: "center", alignment: "left", order: 0, enabled: true }
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

        let currentSection = "";
        let currentAlignment = "";
        let currentOrder = -1;
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (item.id === widgetId) {
                currentSection = item.section;
                currentAlignment = item.alignment;
                currentOrder = item.order;
                break;
            }
        }

        if (currentOrder >= 0 && currentSection === toSection && currentOrder === toOrder) {
            return;
        }

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

    // Returns true if the widget already occupies the given slot
    // including alignment. Used to suppress no-op reorders.
    function isSamePlacement(widgetId, sectionName, order, alignment) {
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (item.id === widgetId)
                return item.section === sectionName && item.order === order && item.alignment === alignment;
        }
        return false;
    }

    // Returns the stable instance key for the widget at layoutModel[modelIndex].
    // Key format: "{widgetId}_{n}" where n counts how many prior entries share the same widgetId.
    function instanceKeyAt(modelIndex) {
        if (modelIndex < 0 || modelIndex >= layoutModel.count) return "";
        let targetId = layoutModel.get(modelIndex).id;
        let n = 0;
        for (let i = 0; i < modelIndex; i++) {
            if (layoutModel.get(i).id === targetId) n++;
        }
        return targetId + "_" + n;
    }

    function resetLayout() {
        layoutModel.clear();
        for (let i = 0; i < defaultLayout.length; i++) {
            layoutModel.append(defaultLayout[i]);
        }
    }

    // Inserts a new widget instance at the end of the given section.
    function addWidget(widgetId, section) {
        let maxOrder = -1;
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (item.section === section && item.order > maxOrder)
                maxOrder = item.order;
        }
        layoutModel.append({
            id: widgetId,
            section: section,
            alignment: "left",
            order: maxOrder + 1,
            enabled: true
        });
        layoutChanged();
        saveLayout();
    }

    // Removes the widget instance identified by instanceKey from the layout model.
    // instanceKey must match what instanceKeyAt() would return for that entry.
    function removeWidget(instanceKey) {
        for (let i = 0; i < layoutModel.count; i++) {
            if (instanceKeyAt(i) === instanceKey) {
                layoutModel.remove(i);
                if (activeWidgetInstanceKey === instanceKey) {
                    widgetSettingsPanelOpen = false;
                    activeWidgetInstanceKey = "";
                }
                layoutChanged();
                saveLayout();
                return;
            }
        }
        console.warn("BarLayoutService: removeWidget called with unknown key:", instanceKey);
    }
}
