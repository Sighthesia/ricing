import QtQuick
import "../../settings/controls"
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Render the registered settings controls for the active-window widget.
Column {
    id: root

    spacing: 10

    readonly property var activeWindowSettings: WidgetSettingsRegistry.settingsObject(
        "active-window",
        Services.SettingsService.widgetSettings
    )

    SettingToggle {
        width: parent.width
        settingLabel: "Show Icon"
        description: "Show the focused app icon before the title."
        checked: root.activeWindowSettings ? root.activeWindowSettings.showIcon : true
        onToggled: value => {
            if (!root.activeWindowSettings)
                return

            root.activeWindowSettings.showIcon = value
        }
    }

    SettingSlider {
        width: parent.width
        settingLabel: "Max Title Width"
        description: "Limit how wide the active title can grow in the bar."
        from: 120
        to: 320
        stepSize: 10
        suffix: "px"
        value: root.activeWindowSettings ? root.activeWindowSettings.maxTitleWidth : 200
        onMoved: value => {
            if (!root.activeWindowSettings)
                return

            root.activeWindowSettings.maxTitleWidth = value
        }
    }

    SettingText {
        width: parent.width
        settingLabel: "Desktop Label"
        description: "Fallback text when no focused app window is available."
        text: root.activeWindowSettings ? root.activeWindowSettings.desktopLabel : "Desktop"
        placeholderText: "Desktop"
        onEdited: value => {
            if (!root.activeWindowSettings)
                return

            root.activeWindowSettings.desktopLabel = value.trim() !== "" ? value.trim() : "Desktop"
        }
    }
}
