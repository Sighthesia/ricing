import QtQuick
import "./" as Services

// Text wrapper that respects global font family and scale settings.
// Drop-in for `Text` – bar widgets using `font.pixelSize: Services.TextSize.barContent`
// can switch to `FluidText {}` and get font-family + scale reactivity for free.
//
// To override the font family for a specific instance, set `explicitFontFamily`:
//   FluidText { explicitFontFamily: "Symbols Nerd Font" }
Text {
    // Set true to use the user's configured monospace font instead of the default.
    property bool useMonospace: false

    // Base pixel size before scale is applied.  Defaults to TextSize.barContent (14px).
    property int basePixelSize: Services.TextSize.barContent

    // Explicit per-instance font family.  When set, this takes precedence over
    // the global font setting — useful for icon-font labels like "Symbols Nerd Font".
    property string explicitFontFamily: ""

    // Font family — falls back through explicit → user preference → system default.
    font.family: {
        if (explicitFontFamily)
            return explicitFontFamily
        if (useMonospace) {
            var fixed = Services.SettingsService.appearance.fontFixed
            return fixed || "monospace"
        }
        var ui = Services.SettingsService.appearance.fontDefault
        return ui || Qt.application.font.family
    }

    // Pixel size with user font scale applied.
    font.pixelSize: {
        var scale = useMonospace
            ? Services.SettingsService.appearance.fontFixedScale
            : Services.SettingsService.appearance.fontDefaultScale
        return Math.round(basePixelSize * (scale || 1.0))
    }
}
