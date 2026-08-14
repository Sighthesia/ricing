import QtQuick
import ".."

// Present appearance settings in a scrollable, service-independent page.
Flickable {
    id: root
    property var settingsObject
    property var saveCallback
    property var wallpaperService
    property string title: "外观"
    property alias wallpaperField: wallpaperFieldInput
    property alias panelOpacitySlider: panelOpacitySliderControl
    property alias blurSurfaceRow: blurSurfaceRowControl
    property alias blurSurfaceSlider: blurSurfaceSliderControl
    contentWidth: width
    contentHeight: pageColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Keep category rows in one vertical, scrollable content column.
    Column {
        id: pageColumn
        width: root.width
        spacing: 8
        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "壁纸路径"; descriptionText: "留空恢复默认壁纸"; LazerSettingsTextField { id: wallpaperFieldInput; text: root.settingsObject ? root.settingsObject.wallpaperPath : ""; placeholderText: "文件路径"; onTextCommitted: function(path) { if (path === "") { root.settingsObject.wallpaperPath = ""; if (root.saveCallback) root.saveCallback() } else if (root.wallpaperService) root.wallpaperService.changeWallpaper(path) }; onClearRequested: function() { root.settingsObject.wallpaperPath = ""; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "配色方案"; descriptionText: "自动、深色或浅色"; LazerSettingsChoice { model: [{value: "auto", label: "自动"}, {value: "dark", label: "深色"}, {value: "light", label: "浅色"}]; currentValue: root.settingsObject ? root.settingsObject.colorScheme : "auto"; onValueSelected: function(value) { root.settingsObject.colorScheme = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "面板不透明度"; descriptionText: "范围 0 到 1"; LazerSettingsSlider { id: panelOpacitySliderControl; from: 0; to: 1; stepSize: 0.05; value: root.settingsObject ? root.settingsObject.panelOpacity : 0.9; onValueModified: function(value) { root.settingsObject.panelOpacity = Math.max(0, Math.min(1, value)); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "启用模糊"; LazerSettingsToggle { checked: root.settingsObject ? root.settingsObject.enableBlur : false; onToggled: function(value) { root.settingsObject.enableBlur = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { id: blurSurfaceRowControl; width: pageColumn.width - 16; x: 8; enabled: root.settingsObject ? root.settingsObject.enableBlur : false; labelText: "模糊表面不透明度"; LazerSettingsSlider { id: blurSurfaceSliderControl; from: 0; to: 1; stepSize: 0.05; value: root.settingsObject ? root.settingsObject.blurSurfaceOpacity : 0.35; onValueModified: function(value) { root.settingsObject.blurSurfaceOpacity = Math.max(0, Math.min(1, value)); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "玻璃高光宽度"; LazerSettingsSlider { from: 0; to: 12; stepSize: 1; value: root.settingsObject ? root.settingsObject.glassHighlightWidth : 2; onValueModified: function(value) { root.settingsObject.glassHighlightWidth = Math.max(0, Math.min(12, value)); if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "主题自适应"; LazerSettingsToggle { checked: root.settingsObject ? root.settingsObject.glassThemeAdaptive : true; onToggled: function(value) { root.settingsObject.glassThemeAdaptive = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "涟漪脉冲"; LazerSettingsToggle { checked: root.settingsObject ? root.settingsObject.ripplePulseEnabled : true; onToggled: function(value) { root.settingsObject.ripplePulseEnabled = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "概览背景"; LazerSettingsToggle { checked: root.settingsObject ? root.settingsObject.overviewBackground : false; onToggled: function(value) { root.settingsObject.overviewBackground = value; if (root.saveCallback) root.saveCallback() } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "概览模糊"; LazerSettingsSlider { from: 0; to: 1; stepSize: 0.05; value: root.settingsObject ? root.settingsObject.overviewBackgroundBlur : 0.4; onValueModified: function(value) { root.settingsObject.overviewBackgroundBlur = Math.max(0, Math.min(1, value)); if (root.saveCallback) root.saveCallback() } } }
    }
}
