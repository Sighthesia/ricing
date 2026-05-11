pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "barlayout/BarLayoutLayoutModel.js" as BarLayoutModel
import "barlayout/BarLayoutSections.js" as BarLayoutSections
import "barlayout/BarLayoutPersistence.js" as BarLayoutPersistence

// Own the default bar layout and expose section lookup helpers.
QtObject {
    id: root

    readonly property int barHeight: 42
    readonly property var layoutModel: BarLayoutModel.normalizeLayoutModel(layoutAdapter.layoutModel)
    readonly property var availableWidgets: BarLayoutModel.availableWidgets()

    readonly property bool layoutReady: layoutFile.loaded
    property bool widgetPickerVisible: false
    property string widgetPickerSection: "center"

    function saveLayoutModel(nextLayoutModel) {
        layoutAdapter.layoutModel = BarLayoutModel.normalizeLayoutModel(nextLayoutModel)
        layoutFile.writeAdapter()
    }

    function addWidgetToSection(widgetId, sectionName) {
        saveLayoutModel(BarLayoutModel.addWidgetToSection(layoutModel, widgetId, sectionName))
    }

    function openWidgetPicker(sectionName) {
        widgetPickerSection = typeof sectionName === "string" && sectionName ? sectionName : "center"
        widgetPickerVisible = true
    }

    function closeWidgetPicker() {
        widgetPickerVisible = false
    }

    function toggleWidgetPicker(sectionName) {
        if (widgetPickerVisible) {
            closeWidgetPicker()
            return
        }

        openWidgetPicker(sectionName)
    }

    function resetLayoutModel() {
        layoutAdapter.layoutModel = BarLayoutModel.defaultLayoutModel()
        layoutFile.writeAdapter()
    }

    function sectionWidgets(sectionName) {
        return BarLayoutModel.sectionWidgets(layoutModel, sectionName);
    }

    function sectionWidth(sectionModel) {
        return BarLayoutSections.sectionWidth(sectionModel);
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
