import QtQuick
import "../../lazerbar"
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Visual separator between bar groups, placeable like any other widget.
// Its ink is its own setting: a divider that cannot be tuned is just a gap,
// and the colour is the one property every divider instance can differ on.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    // Read through the registry so a settings file written by an older build
    // still resolves the shipped defaults instead of handing `undefined` in.
    readonly property var defaults: WidgetSettingsRegistry.defaults("divider")
    readonly property var settings: {
        var stored = Services.SettingsService.widgetSettingsObject("divider", root.instanceKey)
        return stored || root.defaults
    }
    readonly property string colorName: settings && settings.color !== undefined
        ? String(settings.color) : String(root.defaults.color)
    // Resolve the named ink here rather than in the control: the swatch draws
    // samples, the divider draws its rule, and both must agree on each name.
    readonly property color ink: {
        var entry = WidgetSettingsRegistry.swatch(root.colorName)
        var alpha = Math.max(0.05, Math.min(1, Number(settings && settings.opacity !== undefined
            ? settings.opacity : root.defaults.opacity) / 100))
        if (entry.source === "builtin")
            return Qt.rgba(LazerTheme.barIcon.r, LazerTheme.barIcon.g, LazerTheme.barIcon.b, alpha)
        var base = entry.source === "textPrimary" ? LazerTheme.textPrimary
                : entry.source === "textMuted" ? LazerTheme.textMuted
                : entry.source === "osuPink" ? LazerTheme.osuPink
                : entry.source === "osuGreen" ? LazerTheme.osuGreen
                : LazerTheme.barIcon
        return Qt.rgba(base.r, base.g, base.b, alpha)
    }

    implicitWidth: divider.implicitWidth
    implicitHeight: LazerTheme.barWidgetHeight

    Component.onCompleted: {
        if (root.instanceKey !== "")
            Services.SettingsService.ensureWidgetSettings("divider", root.instanceKey)
    }

    BarDivider {
        id: divider

        anchors.centerIn: parent
        color: root.ink
    }
}
