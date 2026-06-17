import QtQuick
import "../../settings/controls"
import "../../bar/MenuVisuals.js" as MenuVisuals
import "../../../services" as Services

// Render instance-scoped settings controls for the system monitor widget.
Column {
    id: root

    spacing: MenuVisuals.smallGap

    readonly property string instanceKey: Services.BarLayoutService.activeWidgetSettingsKey
    readonly property var monitorSettings: Services.SettingsService.widgetSettingsObject("system-monitor", root.instanceKey)

    SettingToggle {
        width: parent.width
        settingLabel: "Show CPU"
        description: "Show current CPU usage percentage."
        checked: root.monitorSettings ? root.monitorSettings.showCpu : true
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "system-monitor",
            root.instanceKey,
            "showCpu",
            value
        )
    }

    SettingToggle {
        width: parent.width
        settingLabel: "Show Memory"
        description: "Show current memory usage percentage."
        checked: root.monitorSettings ? root.monitorSettings.showMemory : true
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "system-monitor",
            root.instanceKey,
            "showMemory",
            value
        )
    }

    SettingToggle {
        width: parent.width
        settingLabel: "Show Network"
        description: "Show compact download and upload throughput."
        checked: root.monitorSettings ? root.monitorSettings.showNetwork : false
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "system-monitor",
            root.instanceKey,
            "showNetwork",
            value
        )
    }

    SettingToggle {
        width: parent.width
        settingLabel: "Show Load"
        description: "Show the rounded one-minute load average."
        checked: root.monitorSettings ? root.monitorSettings.showLoad : false
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "system-monitor",
            root.instanceKey,
            "showLoad",
            value
        )
    }
}
