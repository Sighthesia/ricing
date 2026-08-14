import QtQuick

// Present the supported notification settings in a scrollable category page.
Flickable {
    id: root
    property var settingsObject: null
    property var saveCallback: null
    property string title: "通知"
    property alias dndToggle: dndToggleControl
    property alias maxVisibleSlider: maxVisibleSliderControl
    property alias timeoutSlider: timeoutSliderControl
    property alias positionChoice: positionChoiceControl
    contentWidth: width; contentHeight: pageColumn.implicitHeight; clip: true
    boundsBehavior: Flickable.StopAtBounds

    function save() { if (root.saveCallback) root.saveCallback() }

    function normalizePosition(value) {
        var valid = ["top-left", "top-right", "bottom-left", "bottom-right"]
        return valid.indexOf(value) >= 0 ? value : "top-right"
    }

    // Keep notification controls grouped in one vertically scrollable column.
    Column {
        id: pageColumn; width: root.width; spacing: 8
        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "请勿打扰"; descriptionText: "静音所有通知"; LazerSettingsToggle { id: dndToggleControl; checked: root.settingsObject ? root.settingsObject.dnd : false; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.dnd = value; root.save() } } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "最大显示数量"; descriptionText: "范围 1 到 8"; LazerSettingsSlider { id: maxVisibleSliderControl; from: 1; to: 8; stepSize: 1; value: root.settingsObject ? root.settingsObject.maxVisible : 3; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.maxVisible = Math.round(Math.max(1, Math.min(8, value))); root.save() } } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "通知超时"; descriptionText: "范围 2 到 15 秒"; LazerSettingsSlider { id: timeoutSliderControl; from: 2; to: 15; stepSize: 1; suffix: " 秒"; value: root.settingsObject ? root.settingsObject.timeout / 1000 : 5; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.timeout = Math.round(Math.max(2, Math.min(15, value))) * 1000; root.save() } } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "通知位置"; LazerSettingsChoice { id: positionChoiceControl; model: [{ value: "top-left", label: "左上" }, { value: "top-right", label: "右上" }, { value: "bottom-left", label: "左下" }, { value: "bottom-right", label: "右下" }]; currentValue: root.normalizePosition(root.settingsObject ? root.settingsObject.position : "top-right"); onValueSelected: function(value) { if (root.settingsObject && ["top-left", "top-right", "bottom-left", "bottom-right"].indexOf(value) >= 0) { root.settingsObject.position = value; root.save() } } } }
    }
}
