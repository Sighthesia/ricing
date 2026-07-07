import QtQuick
import "../../settings/controls"
import "../../bar/MenuVisuals.js" as MenuVisuals
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Render the registered settings controls for the clock widget.
Column {
    id: root

    spacing: MenuVisuals.smallGap

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

    SettingText {
        width: parent.width
        settingLabel: "Clock Format"
        description: "Use a Qt format string. Separate date and time with |, for example yyyy.MM.dd|HH:mm."
        text: root.clockSettings ? root.clockSettings.timeFormat : "yyyy.MM.dd|HH:mm"
        placeholderText: "yyyy.MM.dd|HH:mm"
        onEdited: value => {
            if (!root.clockSettings)
                return

            root.clockSettings.timeFormat = value.trim()
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
