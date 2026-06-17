import QtQuick
import "../../settings/controls"
import "../../bar/MenuVisuals.js" as MenuVisuals
import "../../../services" as Services

// Render instance-scoped settings controls for the battery widget.
Column {
    id: root

    spacing: MenuVisuals.smallGap

    readonly property string instanceKey: Services.BarLayoutService.activeWidgetSettingsKey
    readonly property var batterySettings: Services.SettingsService.widgetSettingsObject("battery", root.instanceKey)

    SettingToggle {
        width: parent.width
        settingLabel: "Show Percentage"
        description: "Show the battery percentage in the bar widget."
        checked: root.batterySettings ? root.batterySettings.showPercentage : true
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "battery",
            root.instanceKey,
            "showPercentage",
            value
        )
    }

    SettingToggle {
        width: parent.width
        settingLabel: "Show State Label"
        description: "Show the BAT, CHG, or AC status label before the percentage."
        checked: root.batterySettings ? root.batterySettings.showStateLabel : true
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "battery",
            root.instanceKey,
            "showStateLabel",
            value
        )
    }
}
