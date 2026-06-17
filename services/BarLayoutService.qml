pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "WidgetSettingsRegistry.js" as WidgetSettingsRegistry
import "barlayout/BarLayoutLayoutModel.js" as BarLayoutModel
import "barlayout/BarLayoutSections.js" as BarLayoutSections
import "barlayout/BarLayoutPersistence.js" as BarLayoutPersistence
import "barlayout/BarLayoutDrag.js" as BarLayoutDrag

// Own the bar layout state: model, editing mode, drag, persistence.
QtObject {
    id: root

    readonly property int barHeight: SettingsService.bar.height
    readonly property var layoutModel: BarLayoutModel.normalizeLayoutModel(layoutAdapter.layoutModel)
    readonly property var availableWidgets: BarLayoutModel.availableWidgets()

    readonly property bool layoutReady: layoutFile.loaded
    property bool widgetPickerVisible: false
    property string widgetPickerSection: "center"
    property string widgetPickerScreenName: ""
    property bool widgetSettingsVisible: false
    property real widgetSettingsX: 0
    property string activeWidgetSettingsKey: ""
    property string activeWidgetSettingsId: ""
    property string widgetSettingsSection: "center"
    property string widgetSettingsScreenName: ""

    // --- Layout editing mode ---
    property bool settingsMode: false

    function toggleSettingsMode() {
        settingsMode = !settingsMode
        if (!settingsMode) {
            endDrag()
        }
    }

    function exitSettingsMode() {
        settingsMode = false
        closeWidgetPicker()
        closeContextMenu()
        closeWidgetSettings()
        endDrag()
    }

    // --- Drag state ---
    property bool isDragging: false
    property string draggedInstanceKey: ""
    property string draggedWidgetId: ""
    property real dragVisualCenterX: 0
    property string ghostSection: ""
    property int ghostIndex: -1

    // Section pixel bounds — updated by BarContent when layout changes.
    // Format: [{name: "left", left: 0, right: 200}, ...]
    property var sectionBounds: []

    // Widget centers per section — updated by BarContent on geometry changes.
    // Format: {sectionName: [{instanceKey, centerX}]}
    property var widgetCentersBySection: ({})

    function beginDrag(instanceKey, widgetId, startCenterX) {
        if (!settingsMode) return
        var state = BarLayoutDrag.beginDragState(instanceKey, widgetId, startCenterX)
        isDragging = state.active
        draggedInstanceKey = state.instanceKey
        draggedWidgetId = state.widgetId
        dragVisualCenterX = state.visualCenterX
        ghostSection = ""
        ghostIndex = -1
    }

    function updateDrag(visualCenterX) {
        if (!isDragging) return
        var state = BarLayoutDrag.updateDragState(
            visualCenterX, sectionBounds, widgetCentersBySection, draggedInstanceKey
        )
        dragVisualCenterX = state.visualCenterX
        ghostSection = state.ghostSection
        ghostIndex = state.ghostIndex
    }

    function endDrag() {
        if (!isDragging) {
            draggedInstanceKey = ""
            return
        }

        var result = BarLayoutDrag.endDragResult(ghostSection, ghostIndex, draggedInstanceKey)
        isDragging = false

        if (result.section && result.instanceKey) {
            moveWidget(result.instanceKey, result.section, result.index)
        }

        draggedInstanceKey = ""
        draggedWidgetId = ""
        ghostSection = ""
        ghostIndex = -1
    }

    function cancelDrag() {
        isDragging = false
        draggedInstanceKey = ""
        draggedWidgetId = ""
        ghostSection = ""
        ghostIndex = -1
    }

    // --- Mutations ---
    function saveLayoutModel(nextLayoutModel) {
        layoutAdapter.layoutModel = BarLayoutModel.normalizeLayoutModel(nextLayoutModel)
        layoutFile.writeAdapter()
    }

    function addWidgetToSection(widgetId, sectionName) {
        saveLayoutModel(BarLayoutModel.addWidgetToSection(layoutModel, widgetId, sectionName))
    }

    function removeWidget(instanceKey) {
        SettingsService.removeWidgetInstanceSettings(instanceKey)
        saveLayoutModel(BarLayoutModel.removeWidgetByKey(layoutModel, instanceKey))
    }

    function moveWidget(instanceKey, toSection, toOrder) {
        saveLayoutModel(BarLayoutModel.moveWidgetToSection(layoutModel, instanceKey, toSection, toOrder))
    }

    function resetLayoutModel() {
        layoutAdapter.layoutModel = BarLayoutModel.defaultLayoutModel()
        layoutFile.writeAdapter()
    }

    // --- Context menu state ---
    property bool contextMenuVisible: false
    property real contextMenuX: 0
    property string contextMenuWidgetKey: ""
    property string contextMenuWidgetId: ""
    property string contextMenuSection: "center"
    property string contextMenuScreenName: ""

    function openContextMenu(x, instanceKey, widgetId, screenName) {
        closeWidgetPicker()
        contextMenuX = x
        contextMenuWidgetKey = instanceKey || ""
        contextMenuWidgetId = widgetId || ""
        contextMenuScreenName = screenName || ""
        contextMenuSection = _sectionForX(x)
        contextMenuVisible = true
    }

    // Determine which section a bar-local X coordinate falls in.
    function _sectionForX(x) {
        for (var i = 0; i < sectionBounds.length; i++) {
            if (x >= sectionBounds[i].left && x <= sectionBounds[i].right)
                return sectionBounds[i].name
        }
        return "center"
    }

    function closeContextMenu() {
        contextMenuVisible = false
        contextMenuWidgetKey = ""
        contextMenuWidgetId = ""
        contextMenuScreenName = ""
    }

    function widgetSupportsSettings(widgetId) {
        return WidgetSettingsRegistry.hasSettings(widgetId)
    }

    function openWidgetSettings(instanceKey, widgetId, centerX, screenName, sectionName) {
        if (!widgetSupportsSettings(widgetId))
            return

        closeWidgetPicker()
        closeContextMenu()
        SettingsService.ensureWidgetSettings(widgetId, instanceKey)
        activeWidgetSettingsKey = instanceKey || ""
        activeWidgetSettingsId = widgetId || ""
        widgetSettingsX = centerX || 0
        widgetSettingsSection = sectionName || _sectionForX(widgetSettingsX)
        widgetSettingsScreenName = screenName || ""
        widgetSettingsVisible = true

        if (!settingsMode)
            settingsMode = true
    }

    function closeWidgetSettings() {
        widgetSettingsVisible = false
        activeWidgetSettingsKey = ""
        activeWidgetSettingsId = ""
        widgetSettingsX = 0
        widgetSettingsSection = "center"
        widgetSettingsScreenName = ""
    }

    // --- Widget picker ---
    function openWidgetPicker(sectionName, screenName) {
        closeContextMenu()
        widgetPickerSection = typeof sectionName === "string" && sectionName ? sectionName : "center"
        widgetPickerScreenName = screenName || ""
        widgetPickerVisible = true
        if (!settingsMode)
            settingsMode = true
    }

    function closeWidgetPicker() {
        widgetPickerVisible = false
        widgetPickerScreenName = ""
    }

    function toggleWidgetPicker(sectionName, screenName) {
        if (widgetPickerVisible) {
            closeWidgetPicker()
            return
        }

        openWidgetPicker(sectionName, screenName)
    }

    // --- Query helpers ---
    function sectionWidgets(sectionName) {
        return BarLayoutModel.sectionWidgets(layoutModel, sectionName)
    }

    function sectionWidth(sectionModel) {
        return BarLayoutSections.sectionWidth(sectionModel)
    }

    // Persist the normalized layout model in the shell state directory.
    property FileView layoutFile: FileView {
        id: layoutFile

        path: Quickshell.statePath(BarLayoutPersistence.defaultLayoutPath())
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: {
            var normalizedLayout = BarLayoutModel.normalizeLayoutModel(layoutAdapter.layoutModel)
            if (JSON.stringify(normalizedLayout) !== JSON.stringify(layoutAdapter.layoutModel)) {
                layoutAdapter.layoutModel = normalizedLayout
                writeAdapter()
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                layoutAdapter.layoutModel = BarLayoutModel.defaultLayoutModel()
                writeAdapter()
            }
        }

        JsonAdapter {
            id: layoutAdapter

            property var layoutModel: BarLayoutModel.defaultLayoutModel()
        }

    }

}
