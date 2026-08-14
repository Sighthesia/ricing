import QtQuick
import ".."

// Present notification settings in a scrollable category page.
Flickable {
    id: root
    property var settingsObject
    property var saveCallback
    property string title: "通知"
    property alias maxVisibleSlider: maxVisibleSliderControl
    property alias positionChoice: positionChoiceControl
    contentWidth: width
    contentHeight: pageColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Keep notification limits and policies in separate grouped rows.
    Column {
        id: pageColumn
        width: root.width
        spacing: 8
        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "最大显示数量"; descriptionText: "范围 1 到 10"; LazerSettingsSlider { id: maxVisibleSliderControl; from: 1; to: 10; stepSize: 1; value: root.settingsObject ? root.settingsObject.maxVisible : 3; onValueModified: function(value) { root.settingsObject.maxVisible = Math.max(1, Math.min(10, Math.round(value))); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "通知超时"; descriptionText: "范围 2 到 15 秒"; LazerSettingsSlider { from: 2; to: 15; stepSize: 1; suffix: " 秒"; value: root.settingsObject ? root.settingsObject.timeout / 1000 : 5; onValueModified: function(value) { root.settingsObject.timeout = Math.max(2000, Math.min(15000, Math.round(value * 1000))); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "通知位置"; LazerSettingsChoice { id: positionChoiceControl; model: [{value: "top-left", label: "左上"}, {value: "top-right", label: "右上"}, {value: "bottom-left", label: "左下"}, {value: "bottom-right", label: "右下"}]; currentValue: root.settingsObject ? root.settingsObject.position : "top-right"; onValueSelected: function(value) { root.settingsObject.position = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "请勿打扰"; descriptionText: "静音所有通知"; LazerSettingsToggle { checked: root.settingsObject ? root.settingsObject.dnd : false; onToggled: function(value) { root.settingsObject.dnd = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "通知声音"; LazerSettingsToggle { checked: true } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "桌面通知"; LazerSettingsToggle { checked: true } }
    }
}
