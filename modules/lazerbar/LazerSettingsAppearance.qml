import QtQuick

// Present the supported appearance settings in a scrollable category page.
Flickable {
    id: root
    property var settingsObject: null
    property var saveCallback: null
    property var wallpaperService: null
    property var defaults: ({})
    property var resetCallback: null
    property string title: "外观"
    property string searchQuery: ""
    readonly property int visibleResultCount:
        (wallpaperRow.searchVisible ? 1 : 0)
        + (colorSchemeRow.searchVisible ? 1 : 0)
        + (panelOpacityRow.searchVisible ? 1 : 0)
        + (enableBlurRow.searchVisible ? 1 : 0)
        + (blurSurfaceRow.searchVisible ? 1 : 0)
        + (glassHighlightRow.searchVisible ? 1 : 0)
        + (glassGlowRow.searchVisible ? 1 : 0)
        + (themeAdaptiveRow.searchVisible ? 1 : 0)
        + (rippleRow.searchVisible ? 1 : 0)
    property alias wallpaperField: wallpaperFieldControl
    property alias colorSchemeChoice: colorSchemeChoiceControl
    property alias panelOpacitySlider: panelOpacitySliderControl
    property alias enableBlurToggle: enableBlurToggleControl
    property alias blurSurfaceOpacitySlider: blurSurfaceOpacitySliderControl
    property alias blurSurfaceSlider: blurSurfaceOpacitySliderControl
    property alias glassHighlightIntensitySlider: glassHighlightIntensitySliderControl
    property alias glassGlowIntensitySlider: glassGlowIntensitySliderControl
    property alias glassThemeAdaptiveToggle: glassThemeAdaptiveToggleControl
    property alias ripplePulseToggle: ripplePulseToggleControl
    property alias wallpaperRow: wallpaperRow
    property alias colorSchemeRow: colorSchemeRow
    property alias panelOpacityRow: panelOpacityRow
    property alias enableBlurRow: enableBlurRow
    property alias blurSurfaceRow: blurSurfaceRow
    property alias glassGlowRow: glassGlowRow
    contentWidth: width
    contentHeight: pageColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function save() {
        if (root.saveCallback)
            root.saveCallback()
    }

    // Restore one key to its injected default through the host reset path.
    function resetKey(key) {
        if (root.resetCallback && root.defaults && (key in root.defaults))
            root.resetCallback(key, root.defaults[key])
    }

    function defaultOf(key) {
        return root.defaults && (key in root.defaults) ? root.defaults[key] : undefined
    }

    function normalizeColorScheme(value) {
        return value === "dark" || value === "light" || value === "auto" ? value : "auto"
    }

    // Keep appearance controls grouped in one vertically scrollable column.
    Column {
        id: pageColumn
        width: root.width
        spacing: 8

        Text { text: root.title; color: LazerTheme.textPrimary; font.pixelSize: 22; leftPadding: 16; topPadding: 12 }

        LazerSettingsRow {
            id: wallpaperRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "壁纸路径"; descriptionText: "留空恢复默认壁纸"
            defaultValue: root.defaultOf("wallpaperPath")
            currentValue: root.settingsObject ? root.settingsObject.wallpaperPath : ""
            resetCallback: function() { root.resetKey("wallpaperPath") }
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
            id: colorSchemeRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "配色方案"; descriptionText: "自动、深色或浅色"
            defaultValue: root.defaultOf("colorScheme")
            currentValue: colorSchemeChoiceControl.currentValue
            resetCallback: function() { root.resetKey("colorScheme") }
            LazerSettingsChoice {
                id: colorSchemeChoiceControl
                model: [{ value: "auto", label: "自动" }, { value: "dark", label: "深色" }, { value: "light", label: "浅色" }]
                currentValue: root.normalizeColorScheme(root.settingsObject ? root.settingsObject.colorScheme : "auto")
                onValueSelected: function(value) {
                    if (root.settingsObject && (value === "auto" || value === "dark" || value === "light")) {
                        root.settingsObject.colorScheme = value
                        root.save()
                    }
                }
            }
        }

        LazerSettingsRow {
            id: panelOpacityRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "面板不透明度"; descriptionText: "范围 0.35 到 1"
            defaultValue: root.defaultOf("panelOpacity")
            currentValue: root.settingsObject ? root.settingsObject.panelOpacity : null
            resetCallback: function() { root.resetKey("panelOpacity") }
            LazerSettingsSlider {
                id: panelOpacitySliderControl; from: 0.35; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.panelOpacity : 0.9
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.panelOpacity = Math.max(0.35, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow {
            id: enableBlurRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "启用模糊"
            defaultValue: root.defaultOf("enableBlur")
            currentValue: root.settingsObject ? root.settingsObject.enableBlur : null
            resetCallback: function() { root.resetKey("enableBlur") }
            LazerSettingsToggle {
                id: enableBlurToggleControl; checked: root.settingsObject ? root.settingsObject.enableBlur : false
                onToggled: function(value) { if (root.settingsObject) { root.settingsObject.enableBlur = value; root.save() } }
            }
        }

        LazerSettingsRow {
            id: blurSurfaceRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            enabled: root.settingsObject ? root.settingsObject.enableBlur : false
            labelText: "模糊表面不透明度"; descriptionText: "范围 0 到 1"
            defaultValue: root.defaultOf("blurSurfaceOpacity")
            currentValue: root.settingsObject ? root.settingsObject.blurSurfaceOpacity : null
            resetCallback: function() { root.resetKey("blurSurfaceOpacity") }
            LazerSettingsSlider {
                id: blurSurfaceOpacitySliderControl; from: 0; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.blurSurfaceOpacity : 0.35
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.blurSurfaceOpacity = Math.max(0, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow {
            id: glassHighlightRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "玻璃高光强度"; descriptionText: "范围 0 到 1"
            defaultValue: root.defaultOf("glassHighlightIntensity")
            currentValue: root.settingsObject ? root.settingsObject.glassHighlightIntensity : null
            resetCallback: function() { root.resetKey("glassHighlightIntensity") }
            LazerSettingsSlider {
                id: glassHighlightIntensitySliderControl; from: 0; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.glassHighlightIntensity : 0.56
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.glassHighlightIntensity = Math.max(0, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow {
            id: glassGlowRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "玻璃辉光强度"; descriptionText: "范围 0 到 1"
            defaultValue: root.defaultOf("glassGlowIntensity")
            currentValue: root.settingsObject ? root.settingsObject.glassGlowIntensity : null
            resetCallback: function() { root.resetKey("glassGlowIntensity") }
            LazerSettingsSlider {
                id: glassGlowIntensitySliderControl; from: 0; to: 1; stepSize: 0.05
                value: root.settingsObject ? root.settingsObject.glassGlowIntensity : 0.22
                onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.glassGlowIntensity = Math.max(0, Math.min(1, value)); root.save() } }
            }
        }

        LazerSettingsRow {
            id: themeAdaptiveRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "主题自适应"
            defaultValue: root.defaultOf("glassThemeAdaptive")
            currentValue: root.settingsObject ? root.settingsObject.glassThemeAdaptive : null
            resetCallback: function() { root.resetKey("glassThemeAdaptive") }
            LazerSettingsToggle { id: glassThemeAdaptiveToggleControl; checked: root.settingsObject ? root.settingsObject.glassThemeAdaptive : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.glassThemeAdaptive = value; root.save() } } }
        }
        LazerSettingsRow {
            id: rippleRow
            width: pageColumn.width - 16; x: 8
            searchQuery: root.searchQuery
            labelText: "涟漪脉冲"
            defaultValue: root.defaultOf("ripplePulseEnabled")
            currentValue: root.settingsObject ? root.settingsObject.ripplePulseEnabled : null
            resetCallback: function() { root.resetKey("ripplePulseEnabled") }
            LazerSettingsToggle { id: ripplePulseToggleControl; checked: root.settingsObject ? root.settingsObject.ripplePulseEnabled : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.ripplePulseEnabled = value; root.save() } } }
        }
    }
}