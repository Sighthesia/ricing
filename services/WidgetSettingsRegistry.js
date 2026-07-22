.pragma library

var _definitions = {
    "active-window": {
        title: "Active Window Settings",
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
        title: "Clock Settings",
        settingsKey: "clock",
        panelKey: "clock",
        defaults: {
            showDate: true,
            timeFormat: "yyyy.MM.dd|HH:mm",
            showDateWhenSimplified: false,
        },
    },
    "battery": {
        title: "Battery Settings",
        panelKey: "battery",
        instanceScoped: true,
        defaults: {
            showPercentage: true,
            showStateLabel: true,
        },
    },
    "system-monitor": {
        title: "System Monitor Settings",
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
        title: "Media Settings",
        panelKey: "media",
        instanceScoped: true,
        defaults: {
            lyricsDisplayMode: "Original",
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
        title: "Bluetooth Settings",
        panelKey: "bluetooth",
        instanceScoped: true,
        defaults: {},
    },
    "network": {
        title: "Wi-Fi Settings",
        panelKey: "network",
        instanceScoped: true,
        defaults: {},
    },
    "volume": {
        title: "Volume Settings",
        panelKey: "volume",
        instanceScoped: true,
        defaults: {},
    },
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
