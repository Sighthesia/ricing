import QtQuick
import "../../services" as Services

// Present the supported appearance settings in a scrollable category page.
Flickable {
    id: root
    property var settingsObject: Services.SettingsService.appearance
    property var saveCallback: function() { Services.SettingsService.save() }
    property var wallpaperService: Services.WallpaperService
    property string title: "外观"
    property alias wallpaperField: wallpaperFieldControl
    property alias colorSchemeChoice: colorSchemeChoiceControl
    property alias panelOpacitySlider: panelOpacitySliderControl
    property alias enableBlurToggle: enableBlurToggleControl
    property alias blurSurfaceOpacitySlider: blurSurfaceOpacitySliderControl
    property alias glassHighlightIntensitySlider: glassHighlightIntensitySliderControl
    property alias glassGlowIntensitySlider: glassGlowIntensitySliderControl
    property alias glassThemeAdaptiveToggle: glassThemeAdaptiveToggleControl
    property alias ripplePulseToggle: ripplePulseToggleControl
    property alias blurSurfaceRow: blurSurfaceRowControl
    contentWidth: width
    contentHeight: pageColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function save() {
        if (root.saveCallback)
            root.saveCallback()
    }

    // Keep appearance controls grouped in one vertically scrollable column.
    Column {
        id: pageColumn
        width: root.width
        spacing: 8

        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }

        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8
            labelText: "壁纸路径"; descriptionText: "留空恢复默认壁纸"
            LazerSettingsTextField {
                id: wallpaperFieldControl
                text: root.settingsObject ? root.settingsObject.wallpaperPath : ""
                placeholderText: "文件路径"
                onTextCommitted: function(path) {
                    if (!root.settingsObject)
                        return
                    if (path === "") {
                        root.settingsObject.wallpaperPath = ""
                        root.save()
                    } else if (root.wallpaperService && path !== root.settingsObject.wallpaperPath) {
                        root.wallpaperService.changeWallpaper(path)
                    }
                }
                onClearRequested: function() {
                    if (!root.settingsObject)
                        return
                    if (root.settingsObject.wallpaperPath !== "") {
                        root.settingsObject.wallpaperPath = ""
                        root.save()
                    }
                }
            }
        }

        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8
            labelText: "配色方案"; descriptionText: "自动、深色或浅色"
            LazerSettingsChoice {
                id: colorSchemeChoiceControl
                model: [{ value: "auto", label: "自动" }, { value: "dark", label: "深色" }, { value: "light", label: "浅色" }]
                currentValue: root.settingsObject ? root.settingsObject.colorScheme : "auto"
                onValueSelected: function(value) {
                    if (root.settingsObject && (value === "auto" || value === "dark" || value === "light")) {
                        root.settingsObject.colorScheme = value
                        root.save()
                    }
                }
            }
        }

        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8
            labelText: "面板不透明度"; descriptionText: "范围 0.35 到 1"
            LazerSettingsSlider {
                id: panelOpacitySliderControl; from: 0.35; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.panelOpacity : 0.9
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.panelOpacity = Math.max(0.35, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8; labelText: "启用模糊"
            LazerSettingsToggle {
                id: enableBlurToggleControl; checked: root.settingsObject ? root.settingsObject.enableBlur : false
                onToggled: function(value) { if (root.settingsObject) { root.settingsObject.enableBlur = value; root.save() } }
            }
        }

        LazerSettingsRow {
            id: blurSurfaceRowControl; width: pageColumn.width - 16; x: 8
            enabled: root.settingsObject ? root.settingsObject.enableBlur : false
            labelText: "模糊表面不透明度"; descriptionText: "范围 0 到 1"
            LazerSettingsSlider {
                id: blurSurfaceOpacitySliderControl; from: 0; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.blurSurfaceOpacity : 0.35
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.blurSurfaceOpacity = Math.max(0, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8; labelText: "玻璃高光强度"; descriptionText: "范围 0 到 1"
            LazerSettingsSlider {
                id: glassHighlightIntensitySliderControl; from: 0; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.glassHighlightIntensity : 0.56
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.glassHighlightIntensity = Math.max(0, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow {
            width: pageColumn.width - 16; x: 8; labelText: "玻璃辉光强度"; descriptionText: "范围 0 到 1"
            LazerSettingsSlider {
                id: glassGlowIntensitySliderControl; from: 0; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.glassGlowIntensity : 0.22
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.glassGlowIntensity = Math.max(0, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "主题自适应"; LazerSettingsToggle { id: glassThemeAdaptiveToggleControl; checked: root.settingsObject ? root.settingsObject.glassThemeAdaptive : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.glassThemeAdaptive = value; root.save() } } } }
        LazerSettingsRow { width: pageColumn.width - 16; x: 8; labelText: "涟漪脉冲"; LazerSettingsToggle { id: ripplePulseToggleControl; checked: root.settingsObject ? root.settingsObject.ripplePulseEnabled : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.ripplePulseEnabled = value; root.save() } } } }
    }
}
