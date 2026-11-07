.pragma library

var _definitions = {
    "active-window": {
        title: "widgetSettings.activeWindow",
        settingsKey: "activeWindow",
        panelKey: "active-window",
        defaults: {
            showIcon: true,
            maxTitleWidth: 200,
            maxWidth: 240,
            desktopLabel: "Desktop",
        },
    },
    "clock": {
        title: "widgetSettings.clock",
        settingsKey: "clock",
        panelKey: "clock",
        defaults: {
            showDate: true,
            timeFormat: "yyyy.MM.dd|HH:mm",
            showDateWhenSimplified: false,
        },
    },
    "battery": {
        title: "widgetSettings.battery",
        panelKey: "battery",
        instanceScoped: true,
        defaults: {
            showPercentage: true,
            showStateLabel: true,
        },
    },
    "system-monitor": {
        title: "widgetSettings.systemMonitor",
        panelKey: "system-monitor",
        instanceScoped: true,
        defaults: {
            showCpu: true,
            showMemory: true,
            showNetwork: false,
            showLoad: false,
        },
    },
    "media": {
        title: "widgetSettings.media",
        panelKey: "media",
        instanceScoped: true,
        defaults: {
            lyricsDisplayMode: "Original",
            minWidth: 180,
            maxWidth: 240,
            spectrumHeight: 100,
            spectrumMaxHeight: 100,
            spectrumGain: 100,
            spectrumExpandWithHeight: false,
            spectrumBarWidth: 42,
            spectrumSpacing: 0,
        },
    },
    "bluetooth": {
        title: "widgetSettings.bluetooth",
        panelKey: "bluetooth",
        instanceScoped: true,
        defaults: {},
    },
    "network": {
        title: "widgetSettings.network",
        panelKey: "network",
        instanceScoped: true,
        defaults: {},
    },
    "volume": {
        title: "widgetSettings.volume",
        panelKey: "volume",
        instanceScoped: true,
        defaults: {},
    },
    // Divider is the first widget whose settings are reachable only from the
    // bar's own right-click menu: the shared settings panel has no per-instance
    // page, and a divider is only meaningful in the place it sits. `controls`
    // is what the context menu renders; `defaults` is what persists.
    "divider": {
        title: "widgetSettings.divider",
        panelKey: "divider",
        instanceScoped: true,
        defaults: {
            color: "default",
            opacity: 22,
        },
        controls: [
            { kind: "swatch", settingKey: "color", labelKey: "widgetSettings.divider.color",
              options: ["default", "white", "muted", "pink", "green"] },
            { kind: "slider", settingKey: "opacity", labelKey: "widgetSettings.divider.opacity",
              from: 5, to: 100, stepSize: 1, suffix: "%" },
        ],
    },
}

// Palette the swatch controls offer. Each entry is a symbolic name written to
// settings plus the theme token its ink is drawn from. "builtin" names no token
// on purpose: it means the widget's own rule, so that option keeps following the
// palette when the theme changes instead of freezing a colour that was picked
// against an old wallpaper.
var swatchPalette = {
    "default": { source: "builtin" },
    "white": { source: "textPrimary" },
    "muted": { source: "textMuted" },
    "pink": { source: "osuPink" },
    "green": { source: "osuGreen" },
}

function definition(widgetId) {
    return widgetId && _definitions[widgetId] ? _definitions[widgetId] : null
}

function hasSettings(widgetId) {
    return !!definition(widgetId)
}

function isInstanceScoped(widgetId) {
    var info = definition(widgetId)
    return !!info && info.instanceScoped === true
}

function title(widgetId) {
    var info = definition(widgetId)
    return info && info.title ? info.title : "Widget Settings"
}

function settingsKey(widgetId) {
    var info = definition(widgetId)
    return info && info.settingsKey ? info.settingsKey : ""
}

function panelKey(widgetId) {
    var info = definition(widgetId)
    return info && info.panelKey ? info.panelKey : ""
}

function defaults(widgetId) {
    var info = definition(widgetId)
    return info && info.defaults ? JSON.parse(JSON.stringify(info.defaults)) : ({})
}

// Declarative controls the bar's context menu renders for a widget.
// Deliberately data-only: a widget declares what it exposes, and the menu (or
// any future host) decides how to draw it, so adding a widget setting never
// means editing menu code.
function controls(widgetId) {
    var info = definition(widgetId)
    if (!info || !info.controls)
        return []

    return JSON.parse(JSON.stringify(info.controls))
}

function hasControls(widgetId) {
    return controls(widgetId).length > 0
}

function swatch(name) {
    var entry = swatchPalette[String(name || "default")]
    return entry ? JSON.parse(JSON.stringify(entry)) : JSON.parse(JSON.stringify(swatchPalette["default"]))
}

// Swatch names in the order a control declared them.
function swatchNames(control) {
    if (!control || !control.options)
        return []

    return control.options.slice()
}

function settingsObject(widgetId, settingsRoot) {
    var key = settingsKey(widgetId)
    if (!key || !settingsRoot)
        return null

    return settingsRoot[key] || null
}

function instanceSettingsObject(widgetId, instanceKey, settingsRoot) {
    if (!isInstanceScoped(widgetId) || !instanceKey || !settingsRoot)
        return null

    return settingsRoot[instanceKey] || null
}
