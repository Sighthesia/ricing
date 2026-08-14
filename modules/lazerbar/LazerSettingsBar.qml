import QtQuick
import ".."

// Present status-bar settings in a scrollable category page.
Flickable {
    id: root
    property var settingsObject
    property var saveCallback
    property string title: "状态栏"
    property alias heightSlider: heightSliderControl
    property alias floatingMarginSlider: floatingMarginSliderControl
    contentWidth: width
    contentHeight: pageColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Keep bar settings grouped and vertically readable on narrow screens.
    Column {
        id: pageColumn
        width: root.width
        spacing: 8
        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "状态栏高度"; descriptionText: "范围 24 到 120 像素"; LazerSettingsSlider { id: heightSliderControl; from: 24; to: 120; stepSize: 1; value: root.settingsObject ? root.settingsObject.height : 48; onValueModified: function(value) { root.settingsObject.height = Math.max(24, Math.min(120, Math.round(value))); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "栏位置"; LazerSettingsChoice { model: [{value: "top", label: "顶部"}, {value: "bottom", label: "底部"}]; currentValue: root.settingsObject ? root.settingsObject.position : "top"; onValueSelected: function(value) { root.settingsObject.position = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "浮动模式"; LazerSettingsToggle { checked: root.settingsObject ? root.settingsObject.floating : false; onToggled: function(value) { root.settingsObject.floating = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; enabled: root.settingsObject ? root.settingsObject.floating : false; labelText: "浮动边距"; descriptionText: "范围 0 到 48 像素"; LazerSettingsSlider { id: floatingMarginSliderControl; from: 0; to: 48; stepSize: 1; value: root.settingsObject ? root.settingsObject.floatingMargin : 4; onValueModified: function(value) { root.settingsObject.floatingMargin = Math.max(0, Math.min(48, Math.round(value))); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "圆角半径"; descriptionText: "范围 0 到 32 像素"; LazerSettingsSlider { from: 0; to: 32; stepSize: 1; value: root.settingsObject ? root.settingsObject.cornerRadius : 12; onValueModified: function(value) { root.settingsObject.cornerRadius = Math.max(0, Math.min(32, Math.round(value))); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "紧凑间距"; LazerSettingsToggle { checked: false; onToggled: function(value) { if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "显示分隔线"; LazerSettingsToggle { checked: true; onToggled: function(value) { if (root.saveCallback) root.saveCallback() } } }
    }
}
