import QtQuick
import "../../settings/controls"
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Render the registered settings controls for the clock widget.
Column {
    id: root

    spacing: 10

    readonly property var clockSettings: WidgetSettingsRegistry.settingsObject(
        "clock",
        Services.SettingsService.widgetSettings
    )

    SettingToggle {
        width: parent.width
        settingLabel: "Show Date"
        description: "Show the month and day alongside the time."
        checked: root.clockSettings ? root.clockSettings.showDate : true
        onToggled: value => {
            if (!root.clockSettings)
                return

            root.clockSettings.showDate = value
        }
    }

    SettingDropdown {
        width: parent.width
        settingLabel: "Time Format"
        description: "Choose 12-hour or 24-hour clock output."
        model: ["12h", "24h"]
        currentValue: root.clockSettings ? root.clockSettings.timeFormat : "12h"
        onSelected: value => {
            if (!root.clockSettings)
                return

            root.clockSettings.timeFormat = value
        }
    }

    SettingToggle {
        width: parent.width
        settingLabel: "Date In Compact Mode"
        description: "Keep the date visible even while transient messages simplify the clock."
        checked: root.clockSettings ? root.clockSettings.showDateWhenSimplified : false
        onToggled: value => {
            if (!root.clockSettings)
                return

            root.clockSettings.showDateWhenSimplified = value
        }
    }
}
