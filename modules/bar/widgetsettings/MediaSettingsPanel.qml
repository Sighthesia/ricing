import QtQuick
import "../../settings/controls"
import "../../../services" as Services

// Render instance-scoped settings controls for the media widget.
Column {
    id: root

    spacing: 10

    readonly property string instanceKey: Services.BarLayoutService.activeWidgetSettingsKey
    readonly property var mediaSettings: Services.SettingsService.widgetSettingsObject("media", root.instanceKey)

    SettingToggle {
        width: parent.width
        settingLabel: "Show Audio Spectrum"
        description: "Show the animated audio spectrum behind the compact media widget."
        checked: root.mediaSettings ? root.mediaSettings.showAudioSpectrum : false
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "showAudioSpectrum",
            value
        )
    }
}
