import QtQuick
import "../../settings/controls"
import "../../bar/MenuVisuals.js" as MenuVisuals
import "../../../services" as Services

// Render instance-scoped settings controls for the media widget.
Column {
    id: root

    spacing: MenuVisuals.smallGap

    readonly property string instanceKey: Services.BarLayoutService.activeWidgetSettingsKey
    readonly property var mediaSettings: Services.SettingsService.widgetSettingsObject("media", root.instanceKey)

    SettingDropdown {
        width: parent.width
        settingLabel: "Lyrics Display"
        description: "Choose whether compact lyrics use original text, translation, or both."
        model: ["Original", "Translated", "Original + Translation"]
        currentValue: root.mediaSettings && root.mediaSettings.lyricsDisplayMode
            ? root.mediaSettings.lyricsDisplayMode
            : "Original"
        onSelected: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "lyricsDisplayMode",
            value
        )
    }

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
