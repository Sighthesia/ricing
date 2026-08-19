import QtQuick

// Present the supported notification settings as one flat section block.
LazerSettingsSection {
    id: root
    property var settingsObject: null
    property var saveCallback: null
    property var defaults: ({})
    property var resetCallback: null
    title: "通知"

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
        labelText: "请勿打扰"; descriptionText: "静音所有通知"
        defaultValue: root.defaultOf("dnd")
        currentValue: root.settingsObject ? root.settingsObject.dnd : null
        resetCallback: function() { root.resetKey("dnd") }
        LazerSettingsToggle { id: dndToggleControl; checked: root.settingsObject ? root.settingsObject.dnd : false; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.dnd = value; root.save() } } }
    }
    LazerSettingsRow {
        id: maxVisibleRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "最大显示数量"; descriptionText: "范围 1 到 8"
        defaultValue: root.defaultOf("maxVisible")
        currentValue: root.settingsObject ? root.settingsObject.maxVisible : null
        resetCallback: function() { root.resetKey("maxVisible") }
        LazerSettingsSlider { id: maxVisibleSliderControl; from: 1; to: 8; stepSize: 1; defaultValue: root.defaultOf("maxVisible"); value: root.settingsObject ? root.settingsObject.maxVisible : 3; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.maxVisible = Math.round(Math.max(1, Math.min(8, value))); root.save() } } }
    }
    LazerSettingsRow {
        id: timeoutRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "通知超时"; descriptionText: "范围 2 到 15 秒"
        defaultValue: root.defaultOf("timeout")
        currentValue: root.settingsObject ? root.settingsObject.timeout : null
        resetCallback: function() { root.resetKey("timeout") }
        LazerSettingsSlider { id: timeoutSliderControl; from: 2; to: 15; stepSize: 1; suffix: " 秒"; defaultValue: root.defaultOf("timeout") === undefined ? undefined : root.defaultOf("timeout") / 1000; value: root.settingsObject ? root.settingsObject.timeout / 1000 : 5; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.timeout = Math.round(Math.max(2, Math.min(15, value))) * 1000; root.save() } } }
    }
    LazerSettingsRow {
        id: positionRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "通知位置"
        defaultValue: root.defaultOf("position")
        currentValue: positionChoiceControl.currentValue
        resetCallback: function() { root.resetKey("position") }
        LazerSettingsChoice {
            id: positionChoiceControl
            model: [{ value: "top-left", label: "左上" }, { value: "top-right", label: "右上" }, { value: "bottom-left", label: "左下" }, { value: "bottom-right", label: "右下" }]
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