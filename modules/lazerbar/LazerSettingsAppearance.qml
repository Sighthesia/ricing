import QtQuick
import "../../services/ColorSchemeLogic.js" as ColorLogic
import "../../services/SolarCalc.js" as SolarCalc

// Present the supported appearance settings as one flat section block.
LazerSettingsSection {
    id: root
    property var settingsObject: null
    property var saveCallback: null
    property var wallpaperService: null
    property var defaults: ({})
    property var resetCallback: null
    // Location-mode wiring (injected by the host so this page stays
    // singleton-free and runnable under plain qmltestrunner; the live shell
    // passes Services.LocationService + Services.SettingsService values).
    property var locationService: null
    property string effectiveSunrise: ""
    property string effectiveSunset: ""
    property bool coordsValid: false
    property string locationError: ""
    property string locationDisplayName: ""
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
    property alias cityRow: cityRow
    property alias latitudeRow: latitudeRow
    property alias longitudeRow: longitudeRow
    property alias cityField: cityFieldControl
    property alias latitudeField: latitudeFieldControl
    property alias longitudeField: longitudeFieldControl
    property alias themeSchemePicker: themeSchemePicker
    property alias presetSchemePicker: presetSchemePicker
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
        var text = value != null ? String(value).toLowerCase() : ""
        if (text === "system" || text === "location")
            return text
        return "time"
    }

    function isAutoTimeMode() {
        var intent = normalizeColorScheme(root.settingsObject ? root.settingsObject.colorScheme : "auto")
        var mode = normalizeAutoMode(root.settingsObject ? root.settingsObject.colorSchemeAutoMode : "time")
        return intent === "auto" && mode === "time"
    }

    function isAutoLocationMode() {
        var intent = normalizeColorScheme(root.settingsObject ? root.settingsObject.colorScheme : "auto")
        var mode = normalizeAutoMode(root.settingsObject ? root.settingsObject.colorSchemeAutoMode : "time")
        return intent === "auto" && mode === "location"
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

    // Commit a coordinate edit: keep valid values, snap rejected input back
    // to the stored value so the text binding stays intact.
    function commitCoordinate(field, key, text, isLatitude) {
        if (!root.settingsObject || !field)
            return
        var current = root.settingsObject[key] != null ? String(root.settingsObject[key]) : ""
        var trimmed = String(text).trim()
        var valid = trimmed !== "" && (isLatitude
            ? SolarCalc.isValidLatitude(Number(trimmed))
            : SolarCalc.isValidLongitude(Number(trimmed)))
        if (valid && trimmed !== current) {
            root.settingsObject[key] = trimmed
            root.save()
        }
        field.syncEditorFromText()
    }

    // One-line summary of the solar timetable while in location mode.
    function locationTimetableHint() {
        if (!root.isAutoLocationMode())
            return ""
        if (!root.coordsValid)
            return "填写经纬度或解析城市后自动计算"
        return "按位置算出 " + root.effectiveSunrise + "～" + root.effectiveSunset
    }

    // City commit goes through the injected location service when present
    // (live shell geocodes); otherwise store the text directly (tests).
    // The typed text is persisted first so the async round-trip never wipes
    // the editor and the field binding stays stable throughout.
    function commitCity(field, text) {
        if (!root.settingsObject || !field)
            return
        var next = String(text == null ? "" : text).trim()
        var current = root.settingsObject.autoCity != null ? String(root.settingsObject.autoCity) : ""
        if (next !== current) {
            root.settingsObject.autoCity = next
            root.save()
        }
        cityFieldControl.lastCommittedText = next
        if (root.locationService) {
            // Drop the previous inline error first so the new attempt
            // starts clean; a failure re-sets it via locationError.
            if (root.locationService.clearError)
                root.locationService.clearError()
            root.locationService.geocodeCity(next)
        }
        else if (next === "" && root.locationService)
            root.locationService.clearCity()
        field.syncEditorFromText()
    }

    // A failed geocode must not wedge the field: the text-field dedup would
    // otherwise swallow an identical retry, so reopen commits on error.
    onLocationErrorChanged: {
        if (root.locationError !== "" && cityFieldControl)
            cityFieldControl.lastCommittedText = ""
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
        labelText: "自动模式"; descriptionText: "跟随时间、位置或跟随系统"
        defaultValue: root.defaultOf("colorSchemeAutoMode")
        currentValue: autoModeChoiceControl.currentValue
        resetCallback: function() { root.resetKey("colorSchemeAutoMode") }
        LazerSettingsChoice {
            id: autoModeChoiceControl
            model: [{ value: "time", label: "跟随时间" }, { value: "location", label: "跟随位置" }, { value: "system", label: "跟随系统" }]
            currentValue: root.normalizeAutoMode(root.settingsObject ? root.settingsObject.colorSchemeAutoMode : "time")
            onValueSelected: function(value) {
                if (root.settingsObject && (value === "time" || value === "location" || value === "system")) {
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
        labelText: "日出时间"; descriptionText: root.isAutoLocationMode() ? root.locationTimetableHint() : "自动模式按此切到浅色（HH:MM）"
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
        labelText: "日落时间"; descriptionText: root.isAutoLocationMode() ? root.locationTimetableHint() : "自动模式按此切到深色（HH:MM）"
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

    // Location-driven timetable (cf. noctalia LocationService): city resolves
    // to coordinates, then SolarCalc derives sunrise/sunset offline.
    LazerSettingsRow {
        id: cityRow
        labelText: "城市"
        searchQuery: root.searchQuery
        enabled: root.isAutoLocationMode()
        // A failed geocode surfaces inline under the field instead of a
        // toast; cleared on the next commit attempt or a success.
        footerText: root.locationError
        defaultValue: root.defaultOf("autoCity")
        currentValue: root.settingsObject ? root.settingsObject.autoCity : ""
        resetCallback: function() { root.resetKey("autoCity") }
        LazerSettingsTextField {
            id: cityFieldControl
            text: root.settingsObject ? root.settingsObject.autoCity : ""
            placeholderText: "上海"
            onTextCommitted: function(text) { root.commitCity(cityFieldControl, text) }
            onClearRequested: function() {
                if (root.locationService)
                    root.locationService.clearCity()
                else if (root.settingsObject && root.settingsObject.autoCity !== "") {
                    root.settingsObject.autoCity = ""
                    root.save()
                }
            }
        }
    }

    // Manual coordinates backing the solar timetable (-90..90 / -180..180).
    LazerSettingsRow {
        id: latitudeRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.isAutoLocationMode()
        labelText: "纬度"; descriptionText: "范围 -90 到 90"
        defaultValue: root.defaultOf("autoLatitude")
        currentValue: root.settingsObject ? root.settingsObject.autoLatitude : ""
        resetCallback: function() { root.resetKey("autoLatitude") }
        LazerSettingsTextField {
            id: latitudeFieldControl
            text: root.settingsObject ? root.settingsObject.autoLatitude : ""
            placeholderText: "31.23"
            onTextCommitted: function(text) { root.commitCoordinate(latitudeFieldControl, "autoLatitude", text, true) }
        }
    }

    // Manual coordinates backing the solar timetable (-90..90 / -180..180).
    LazerSettingsRow {
        id: longitudeRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        enabled: root.isAutoLocationMode()
        labelText: "经度"; descriptionText: "范围 -180 到 180"
        defaultValue: root.defaultOf("autoLongitude")
        currentValue: root.settingsObject ? root.settingsObject.autoLongitude : ""
        resetCallback: function() { root.resetKey("autoLongitude") }
        LazerSettingsTextField {
            id: longitudeFieldControl
            text: root.settingsObject ? root.settingsObject.autoLongitude : ""
            placeholderText: "121.47"
            onTextCommitted: function(text) { root.commitCoordinate(longitudeFieldControl, "autoLongitude", text, false) }
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

    // Push system light/dark preference independently of template sync.
    LazerSettingsRow {
        id: syncSystemThemeRow
        width: parent.width - 16; x: 8
        searchQuery: root.searchQuery
        labelText: "同步系统亮暗"; descriptionText: "亮暗变化时推送系统色偏好，Electron/portal 应用跟随"
        defaultValue: root.defaultOf("syncSystemTheme")
        currentValue: root.settingsObject ? root.settingsObject.syncSystemTheme : null
        resetCallback: function() { root.resetKey("syncSystemTheme") }
        LazerSettingsToggle { id: syncSystemThemeToggleControl; checked: root.settingsObject ? root.settingsObject.syncSystemTheme !== false : true; onToggled: function(value) { if (root.settingsObject) { root.settingsObject.syncSystemTheme = value; root.save() } } }
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
