.pragma library

// Pure view model for the bar's right-click widget settings block.
//
// A widget declares its adjustable values in WidgetSettingsRegistry; this file
// turns that declaration plus the live settings object into the rows the menu
// draws. Keeping the derivation here means adding a widget setting is a
// registry entry, never an edit to the menu, and the value fallbacks can be
// read without instantiating QML.
//
// The registry is passed in rather than imported: the caller already imports it
// and QML resolves library imports per scope, so a nested `.import` would give
// this file a second copy of the same module.

// One row per declared control, describing SHAPE only: kind, label, range and
// shipped default. The live value is deliberately NOT resolved here.
//
// That separation is what keeps a slider usable. Every settings write bumps the
// service revision, so a row list carrying values would be rebuilt mid-drag and
// the delegate (the slider the pointer is holding) would be destroyed on the
// first tick. Rows therefore stay stable for as long as the widget does, and
// each control binds its own value from the service.
function rows(registry, widgetId) {
    var declared = registry.controls(widgetId)
    var defaults = registry.defaults(widgetId)
    var result = []

    for (var index = 0; index < declared.length; index++) {
        var control = declared[index]
        var shippedDefault = defaults[control.settingKey]

        var row = {
            kind: String(control.kind || ""),
            settingKey: String(control.settingKey || ""),
            labelKey: String(control.labelKey || ""),
            defaultValue: shippedDefault,
        }

        if (row.kind === "swatch") {
            row.options = swatchOptions(registry, control)
            row.defaultValue = String(shippedDefault !== undefined ? shippedDefault : "default")
        } else if (row.kind === "slider") {
            row.from = Number(control.from !== undefined ? control.from : 0)
            row.to = Number(control.to !== undefined ? control.to : 100)
            row.stepSize = Number(control.stepSize !== undefined ? control.stepSize : 1)
            row.suffix = String(control.suffix || "")
            row.defaultValue = Number(shippedDefault)
        }

        result.push(row)
    }

    return result
}

// Current value of one declared setting, or its shipped default when the stored
// object has never carried the key.
function valueOf(registry, widgetId, settings, settingKey) {
    var live = settings || ({})
    if (live[settingKey] !== undefined && live[settingKey] !== null)
        return live[settingKey]

    return registry.defaults(widgetId)[settingKey]
}

// [{ value, source }] — the symbolic name plus which token paints it. The host
// owns the actual colours so this file never needs the theme singleton.
function swatchOptions(registry, control) {
    var names = registry.swatchNames(control)
    var options = []

    for (var index = 0; index < names.length; index++) {
        var entry = registry.swatch(names[index])
        options.push({ value: String(names[index]), source: String(entry.source || "builtin") })
    }

    return options
}

// True when a widget has anything worth opening a settings block for.
function available(registry, widgetId) {
    return registry.hasControls(widgetId)
}
