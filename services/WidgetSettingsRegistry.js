.pragma library

var _definitions = {
    "clock": {
        title: "Clock Settings",
        settingsKey: "clock",
        defaults: {
            showDate: true,
            timeFormat: "12h",
            showDateWhenSimplified: false,
        },
    },
}

var _panelComponents = {}

function definition(widgetId) {
    return widgetId && _definitions[widgetId] ? _definitions[widgetId] : null
}

function registerPanel(widgetId, component) {
    if (!widgetId || !component)
        return

    _panelComponents[widgetId] = component
}

function panelComponent(widgetId) {
    return widgetId && _panelComponents[widgetId] ? _panelComponents[widgetId] : null
}

function hasSettings(widgetId) {
    return !!definition(widgetId) && !!panelComponent(widgetId)
}

function title(widgetId) {
    var info = definition(widgetId)
    return info && info.title ? info.title : "Widget Settings"
}

function settingsKey(widgetId) {
    var info = definition(widgetId)
    return info && info.settingsKey ? info.settingsKey : ""
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
