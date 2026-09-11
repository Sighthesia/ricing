import QtQuick
import "../../services/ColorSchemeLogic.js" as ColorLogic

// Present the supported appearance settings as one flat section block.
LazerSettingsSection {
    id: root
    property var settingsObject: null
    property var saveCallback: null
    property var wallpaperService: null
    property var defaults: ({})
    property var resetCallback: null
    title: "外观"

    property alias wallpaperField: wallpaperFieldControl
    property alias colorSchemeChoice: colorSchemeChoiceControl
    property alias autoModeChoice: autoModeChoiceControl
    property alias sunriseField: sunriseFieldControl
    property alias sunsetField: sunsetFieldControl
    property alias panelOpacitySlider: panelOpacitySliderControl
    property alias enableBlurToggle: enableBlurToggleControl
    property alias blurSurfaceOpacitySlider: blurSurfaceOpacitySliderControl
    property alias blurSurfaceSlider: blurSurfaceOpacitySliderControl
    property alias glassHighlightIntensitySlider: glassHighlightIntensitySliderControl
    property alias glassGlowIntensitySlider: glassGlowIntensitySliderControl
    property alias glassThemeAdaptiveToggle: glassThemeAdaptiveToggleControl
    property alias themeAdaptationToggle: themeAdaptationToggleControl
    property alias ripplePulseToggle: ripplePulseToggleControl
    property alias wallpaperRow: wallpaperRow
    property alias colorSchemeRow: colorSchemeRow
    property alias autoModeRow: autoModeRow
    property alias sunriseRow: sunriseRow
    property alias sunsetRow: sunsetRow
    property alias themeSchemePicker: themeSchemePicker
    property alias panelOpacityRow: panelOpacityRow
    property alias enableBlurRow: enableBlurRow
    property alias blurSurfaceRow: blurSurfaceRow
    property alias overviewBackgroundRow: overviewBackgroundRow
    property alias overviewSolidRow: overviewSolidRow
    property alias overviewBlurRow: overviewBlurRow
    property alias overviewTintRow: overviewTintRow
    property alias glassGlowRow: glassGlowRow

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

    function normalizeAutoMode(value) {
        return value === "system" ? "system" : "time"
    }

    function isAutoTimeMode() {
        var intent = normalizeColorScheme(root.settingsObject ? root.settingsObject.colorScheme : "auto")
        var mode = normalizeAutoMode(root.settingsObject ? root.settingsObject.colorSchemeAutoMode : "time")
        return intent === "auto" && mode === "time"
    }

    function isAutoMode() {
        return normalizeColorScheme(root.settingsObject ? root.settingsObject.colorScheme : "auto") === "auto"
    }

    // Commit an HH:MM time edit: normalize liberal input ("6:5" -> "06:05"),
    // persist valid values, and snap rejected input back to the stored value.
    // The snap reuses the field's own sync so the text binding stays intact.
    function commitTime(field, key, text, fallback) {
        if (!root.settingsObject || !field)
            return
        var current = root.settingsObject[key] != null ? String(root.settingsObject[key]) : ""
        var normalized = ColorLogic.normalizeTimeString(text, current || fallback)
        if (normalized !== current) {
            root.settingsObject[key] = normalized
            root.save()
        }
        field.syncEditorFromText()
    }

    LazerSettingsRow {
        id: wallpaperRow
        width: parent.width - 16; x: 8
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
        width: parent.width - 16; x: 8
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

    // Automatic switching timetable: only editable while the scheme is auto.
    LazerSettingsRow {
        id: autoModeRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.isAutoMode()
        labelText: "自动模式"; descriptionText: "跟随时间或跟随系统"
        defaultValue: root.defaultOf("colorSchemeAutoMode")
        currentValue: autoModeChoiceControl.currentValue
        resetCallback: function() { root.resetKey("colorSchemeAutoMode") }
        LazerSettingsChoice {
            id: autoModeChoiceControl
            model: [{ value: "time", label: "跟随时间" }, { value: "system", label: "跟随系统" }]
            currentValue: root.normalizeAutoMode(root.settingsObject ? root.settingsObject.colorSchemeAutoMode : "time")
            onValueSelected: function(value) {
                if (root.settingsObject && (value === "time" || value === "system")) {
                    root.settingsObject.colorSchemeAutoMode = value
                    root.save()
                }
            }
        }
    }

    LazerSettingsRow {
        id: sunriseRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.isAutoTimeMode()
        labelText: "日出时间"; descriptionText: "自动模式按此切到浅色（HH:MM）"
        defaultValue: root.defaultOf("autoSunrise")
        currentValue: root.settingsObject ? root.settingsObject.autoSunrise : ""
        resetCallback: function() { root.resetKey("autoSunrise") }
        LazerSettingsTextField {
            id: sunriseFieldControl
            text: root.settingsObject ? root.settingsObject.autoSunrise : ""
            placeholderText: "06:30"
            onTextCommitted: function(text) { root.commitTime(sunriseFieldControl, "autoSunrise", text, "06:30") }
        }
    }

    LazerSettingsRow {
        id: sunsetRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.isAutoTimeMode()
        labelText: "日落时间"; descriptionText: "自动模式按此切到深色（HH:MM）"
        defaultValue: root.defaultOf("autoSunset")
        currentValue: root.settingsObject ? root.settingsObject.autoSunset : ""
        resetCallback: function() { root.resetKey("autoSunset") }
        LazerSettingsTextField {
            id: sunsetFieldControl
            text: root.settingsObject ? root.settingsObject.autoSunset : ""
            placeholderText: "18:30"
            onTextCommitted: function(text) { root.commitTime(sunsetFieldControl, "autoSunset", text, "18:30") }
        }
    }

    // Theme template cards previewing the wallpaper palette per scheme.
    ThemeSchemePicker {
        id: themeSchemePicker
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        settingsObject: root.settingsObject
        saveCallback: root.saveCallback
        defaults: root.defaults
        resetCallback: function(key, value) { root.resetKey(key) }
    }

    LazerSettingsRow {
        id: panelOpacityRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "面板不透明度"; descriptionText: "范围 0.35 到 1"
        defaultValue: root.defaultOf("panelOpacity")
        currentValue: root.settingsObject ? root.settingsObject.panelOpacity : null
        resetCallback: function() { root.resetKey("panelOpacity") }
        LazerSettingsSlider {
            id: panelOpacitySliderControl; from: 0.35; to: 1; stepSize: 0.05
            defaultValue: root.defaultOf("panelOpacity")
            value: root.settingsObject ? root.settingsObject.panelOpacity : 0.9
            onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.panelOpacity = Math.max(0.35, Math.min(1, value)); root.save() } }
        }
    }

    LazerSettingsRow {
        id: enableBlurRow
        width: parent.width - 16; x: 8
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
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.settingsObject ? root.settingsObject.enableBlur : false
        labelText: "模糊表面不透明度"; descriptionText: "范围 0 到 1"
        defaultValue: root.defaultOf("blurSurfaceOpacity")
        currentValue: root.settingsObject ? root.settingsObject.blurSurfaceOpacity : null
        resetCallback: function() { root.resetKey("blurSurfaceOpacity") }
        LazerSettingsSlider {
            id: blurSurfaceOpacitySliderControl; from: 0; to: 1; stepSize: 0.05
            defaultValue: root.defaultOf("blurSurfaceOpacity")
            value: root.settingsObject ? root.settingsObject.blurSurfaceOpacity : 0.35
            onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.blurSurfaceOpacity = Math.max(0, Math.min(1, value)); root.save() } }
        }
    }

    // niri overview backdrop — wallpaper blur/tint rendered inside niri's overview
    LazerSettingsRow {
        id: overviewBackgroundRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "概览背景"; descriptionText: "在 niri 概览中显示壁纸背景"
        defaultValue: root.defaultOf("overviewBackground")
        currentValue: root.settingsObject ? root.settingsObject.overviewBackground : null
        resetCallback: function() { root.resetKey("overviewBackground") }
        LazerSettingsToggle {
            id: overviewBackgroundToggleControl
            checked: root.settingsObject ? root.settingsObject.overviewBackground : false
            onToggled: function(value) { if (root.settingsObject) { root.settingsObject.overviewBackground = value; root.save() } }
        }
    }

    LazerSettingsRow {
        id: overviewSolidRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.settingsObject ? root.settingsObject.overviewBackground : false
        labelText: "概览纯色背景"; descriptionText: "使用纯色而非壁纸"
        defaultValue: root.defaultOf("overviewBackgroundSolid")
        currentValue: root.settingsObject ? root.settingsObject.overviewBackgroundSolid : null
        resetCallback: function() { root.resetKey("overviewBackgroundSolid") }
        LazerSettingsToggle {
            id: overviewSolidToggleControl
            checked: root.settingsObject ? root.settingsObject.overviewBackgroundSolid : false
            onToggled: function(value) { if (root.settingsObject) { root.settingsObject.overviewBackgroundSolid = value; root.save() } }
        }
    }

    LazerSettingsRow {
        id: overviewBlurRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.settingsObject ? (root.settingsObject.overviewBackground && !root.settingsObject.overviewBackgroundSolid) : false
        labelText: "概览模糊"; descriptionText: "范围 0 到 1"
        defaultValue: root.defaultOf("overviewBackgroundBlur")
        currentValue: root.settingsObject ? root.settingsObject.overviewBackgroundBlur : null
        resetCallback: function() { root.resetKey("overviewBackgroundBlur") }
        LazerSettingsSlider {
            id: overviewBlurSliderControl; from: 0; to: 1; stepSize: 0.05
            defaultValue: root.defaultOf("overviewBackgroundBlur")
            value: root.settingsObject ? root.settingsObject.overviewBackgroundBlur : 0.4
            onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.overviewBackgroundBlur = Math.max(0, Math.min(1, value)); root.save() } }
        }
    }

    LazerSettingsRow {
        id: overviewTintRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.settingsObject ? root.settingsObject.overviewBackground : false
        labelText: "概览着色"; descriptionText: "范围 0 到 1"
        defaultValue: root.defaultOf("overviewBackgroundTint")
        currentValue: root.settingsObject ? root.settingsObject.overviewBackgroundTint : null
        resetCallback: function() { root.resetKey("overviewBackgroundTint") }
        LazerSettingsSlider {
            id: overviewTintSliderControl; from: 0; to: 1; stepSize: 0.05
            defaultValue: root.defaultOf("overviewBackgroundTint")
            value: root.settingsObject ? root.settingsObject.overviewBackgroundTint : 0.5
            onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.overviewBackgroundTint = Math.max(0, Math.min(1, value)); root.save() } }
        }
    }

    LazerSettingsRow {
        id: glassHighlightRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "玻璃高光强度"; descriptionText: "范围 0 到 1"
        defaultValue: root.defaultOf("glassHighlightIntensity")
        currentValue: root.settingsObject ? root.settingsObject.glassHighlightIntensity : null
        resetCallback: function() { root.resetKey("glassHighlightIntensity") }
        LazerSettingsSlider {
            id: glassHighlightIntensitySliderControl; from: 0; to: 1; stepSize: 0.05
            defaultValue: root.defaultOf("glassHighlightIntensity")
            value: root.settingsObject ? root.settingsObject.glassHighlightIntensity : 0.56
            onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.glassHighlightIntensity = Math.max(0, Math.min(1, value)); root.save() } }
        }
    }

    LazerSettingsRow {
        id: glassGlowRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "玻璃辉光强度"; descriptionText: "范围 0 到 1"
        defaultValue: root.defaultOf("glassGlowIntensity")
        currentValue: root.settingsObject ? root.settingsObject.glassGlowIntensity : null
        resetCallback: function() { root.resetKey("glassGlowIntensity") }
        LazerSettingsSlider {
            id: glassGlowIntensitySliderControl; from: 0; to: 1; stepSize: 0.05
            defaultValue: root.defaultOf("glassGlowIntensity")
            value: root.settingsObject ? root.settingsObject.glassGlowIntensity : 0.22
            onValueModified: function(value) { if (root.settingsObject) { root.settingsObject.glassGlowIntensity = Math.max(0, Math.min(1, value)); root.save() } }
        }
    }

    LazerSettingsRow {
        id: themeAdaptiveRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "主题自适应"
        defaultValue: root.defaultOf("glassThemeAdaptive")
        currentValue: root.settingsObject ? root.settingsObject.glassThemeAdaptive : null
        resetCallback: function() { root.resetKey("glassThemeAdaptive") }
        LazerSettingsToggle { id: glassThemeAdaptiveToggleControl; checked: root.settingsObject ? root.settingsObject.glassThemeAdaptive : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.glassThemeAdaptive = value; root.save() } } }
    }
    LazerSettingsRow {
        id: themeAdaptationRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "壁纸主题色"; descriptionText: "从壁纸提取主题色并应用到界面"
        defaultValue: root.defaultOf("themeAdaptation")
        currentValue: root.settingsObject ? root.settingsObject.themeAdaptation : null
        resetCallback: function() { root.resetKey("themeAdaptation") }
        LazerSettingsToggle { id: themeAdaptationToggleControl; checked: root.settingsObject ? root.settingsObject.themeAdaptation !== false : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.themeAdaptation = value; root.save() } } }
    }

    // Preset color scheme cards (active while wallpaper adaptation is off).
    PresetSchemePicker {
        id: presetSchemePicker
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        settingsObject: root.settingsObject
        saveCallback: root.saveCallback
    }

    LazerSettingsRow {
        id: syncAppThemesRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "同步应用主题"; descriptionText: "亮暗或配色变化时同步 GTK/Qt/kitty 与系统色"
        defaultValue: root.defaultOf("syncAppThemes")
        currentValue: root.settingsObject ? root.settingsObject.syncAppThemes : null
        resetCallback: function() { root.resetKey("syncAppThemes") }
        LazerSettingsToggle { id: syncAppThemesToggleControl; checked: root.settingsObject ? root.settingsObject.syncAppThemes === true : false; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.syncAppThemes = value; root.save() } } }
    }
    LazerSettingsRow {
        id: terminalClearTextRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "透明终端清晰字"; descriptionText: "透明背景下终端文字全亮度绘制，用颜色区分层级"
        defaultValue: root.defaultOf("terminalClearText")
        currentValue: root.settingsObject ? root.settingsObject.terminalClearText : null
        resetCallback: function() { root.resetKey("terminalClearText") }
        LazerSettingsToggle { id: terminalClearTextToggleControl; checked: root.settingsObject ? root.settingsObject.terminalClearText !== false : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.terminalClearText = value; root.save() } } }
    }
    LazerSettingsRow {
        id: rippleRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "涟漪脉冲"
        defaultValue: root.defaultOf("ripplePulseEnabled")
        currentValue: root.settingsObject ? root.settingsObject.ripplePulseEnabled : null
        resetCallback: function() { root.resetKey("ripplePulseEnabled") }
        LazerSettingsToggle { id: ripplePulseToggleControl; checked: root.settingsObject ? root.settingsObject.ripplePulseEnabled : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.ripplePulseEnabled = value; root.save() } } }
    }
}