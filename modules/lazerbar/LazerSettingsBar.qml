import QtQuick
import "../../services" as Services

// Present the supported top-bar settings in a scrollable category page.
Flickable {
    id: root
    property var settingsObject: Services.SettingsService.bar
    property var saveCallback: function() { Services.SettingsService.save() }
    property string title: "顶部栏"
    property alias heightSlider: heightSliderControl
    property alias positionChoice: positionChoiceControl
    property alias floatingToggle: floatingToggleControl
    property alias floatingMarginSlider: floatingMarginSliderControl
    property alias floatingMarginRow: floatingMarginRowControl
    property alias cornerRadiusSlider: cornerRadiusSliderControl
    contentWidth: width; contentHeight: pageColumn.implicitHeight; clip: true
    boundsBehavior: Flickable.StopAtBounds

    function save() { if (root.saveCallback) root.saveCallback() }

    // Keep top-bar controls grouped in one vertically scrollable column.
    Column {
        id: pageColumn; width: root.width; spacing: 8
        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }
        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8; labelText: "顶部栏高度"; descriptionText: "范围 40 到 64 像素"
            LazerSettingsSlider { id: heightSliderControl; from: 40; to: 64; stepSize: 1; value: root.settingsObject ? root.settingsObject.height : 48; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.height = Math.round(Math.max(40, Math.min(64, value))); root.save() } } }
        }
        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8; labelText: "栏位置"
            LazerSettingsChoice { id: positionChoiceControl; model: [{ value: "top", label: "顶部" }, { value: "bottom", label: "底部" }]; currentValue: root.settingsObject ? root.settingsObject.position : "top"; onValueSelected: function(value) { if (root.settingsObject && (value === "top" || value === "bottom")) { root.settingsObject.position = value; root.save() } } }
        }
        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8; labelText: "浮动模式"
            LazerSettingsToggle { id: floatingToggleControl; checked: root.settingsObject ? root.settingsObject.floating : false; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.floating = value; root.save() } } }
        }
        LazerSettingsRow {
            id: floatingMarginRowControl; width: pageColumn.width - 16; x: 8
            enabled: root.settingsObject ? root.settingsObject.floating : false; labelText: "浮动边距"; descriptionText: "范围 0 到 24 像素"
            LazerSettingsSlider { id: floatingMarginSliderControl; from: 0; to: 24; stepSize: 1; value: root.settingsObject ? root.settingsObject.floatingMargin : 4; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.floatingMargin = Math.round(Math.max(0, Math.min(24, value))); root.save() } } }
        }
        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8; labelText: "圆角半径"; descriptionText: "范围 0 到 24 像素"
            LazerSettingsSlider { id: cornerRadiusSliderControl; from: 0; to: 24; stepSize: 1; value: root.settingsObject ? root.settingsObject.cornerRadius : 12; onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.cornerRadius = Math.round(Math.max(0, Math.min(24, value))); root.save() } } }
        }
    }
}
