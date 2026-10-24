import QtQuick
import "../../services" as Services

// Present the supported notification settings as one flat section block.
LazerSettingsSection {
    id: root
    property var settingsObject: null
    property var saveCallback: null
    property var defaults: ({})
    property var resetCallback: null
    title: Services.Tr.q("settings.notifications")

    property alias dndToggle: dndToggleControl
    property alias maxVisibleSlider: maxVisibleSliderControl
    property alias timeoutSlider: timeoutSliderControl
    property alias positionChoice: positionChoiceControl
    property alias dndRow: dndRow
    property alias maxVisibleRow: maxVisibleRow
    property alias timeoutRow: timeoutRow
    property alias positionRow: positionRow

    function save() { if (root.saveCallback) root.saveCallback() }

    // Restore one key to its injected default through the host reset path.
    function resetKey(key) {
        if (root.resetCallback && root.defaults && (key in root.defaults))
            root.resetCallback(key, root.defaults[key])
    }

    function defaultOf(key) {
        return root.defaults && (key in root.defaults) ? root.defaults[key] : undefined
    }

    function normalizePosition(value) {
        var valid = ["top-left", "top-right", "bottom-left", "bottom-right"]
        return valid.indexOf(value) >= 0 ? value : "top-right"
    }

    LazerSettingsRow {
        id: dndRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: Services.Tr.q("settings.dnd"); descriptionText: Services.Tr.q("settings.dnd.description")
        defaultValue: root.defaultOf("dnd")
        currentValue: root.settingsObject ? root.settingsObject.dnd : null
        resetCallback: function() { root.resetKey("dnd") }
        LazerSettingsToggle { id: dndToggleControl; checked: root.settingsObject ? root.settingsObject.dnd : false; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.dnd = value; root.save() } } }
    }
    LazerSettingsRow {
        id: maxVisibleRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: Services.Tr.q("settings.maxVisible"); descriptionText: Services.Tr.q("settings.maxVisible.description")
        defaultValue: root.defaultOf("maxVisible")
        currentValue: root.settingsObject ? root.settingsObject.maxVisible : null
        resetCallback: function() { root.resetKey("maxVisible") }
        LazerSettingsSlider { id: maxVisibleSliderControl; from: 1; to: 8; stepSize: 1; defaultValue: root.defaultOf("maxVisible"); value: root.settingsObject ? root.settingsObject.maxVisible : 3; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.maxVisible = Math.round(Math.max(1, Math.min(8, value))); root.save() } } }
    }
    LazerSettingsRow {
        id: timeoutRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: Services.Tr.q("settings.timeout"); descriptionText: Services.Tr.q("settings.timeout.description")
        defaultValue: root.defaultOf("timeout")
        currentValue: root.settingsObject ? root.settingsObject.timeout : null
        resetCallback: function() { root.resetKey("timeout") }
        LazerSettingsSlider { id: timeoutSliderControl; from: 2; to: 15; stepSize: 1; suffix: Services.Tr.q("common.seconds"); defaultValue: root.defaultOf("timeout") === undefined ? undefined : root.defaultOf("timeout") / 1000; value: root.settingsObject ? root.settingsObject.timeout / 1000 : 5; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.timeout = Math.round(Math.max(2, Math.min(15, value))) * 1000; root.save() } } }
    }
    LazerSettingsRow {
        id: positionRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: Services.Tr.q("settings.notificationPosition")
        defaultValue: root.defaultOf("position")
        currentValue: positionChoiceControl.currentValue
        resetCallback: function() { root.resetKey("position") }
        LazerSettingsChoice {
            id: positionChoiceControl
            model: [{ value: "top-left", label: Services.Tr.q("settings.notificationPosition.topLeft") }, { value: "top-right", label: Services.Tr.q("settings.notificationPosition.topRight") }, { value: "bottom-left", label: Services.Tr.q("settings.notificationPosition.bottomLeft") }, { value: "bottom-right", label: Services.Tr.q("settings.notificationPosition.bottomRight") }]
            currentValue: root.normalizePosition(root.settingsObject ? root.settingsObject.position : "top-right")
            onValueSelected: function(value) {
                if (root.settingsObject && ["top-left", "top-right", "bottom-left", "bottom-right"].indexOf(value) >= 0) {
                    root.settingsObject.position = value
                    root.save()
                }
            }
        }
    }
}