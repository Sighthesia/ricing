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

    SettingSlider {
        width: parent.width
        settingLabel: "Max Widget Width"
        description: "Limit how wide the media widget can grow in the bar."
        from: 140
        to: 420
        stepSize: 10
        suffix: "px"
        value: root.mediaSettings ? root.mediaSettings.maxWidth : 240
        onMoved: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "maxWidth",
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

    SettingDropdown {
        width: parent.width
        settingLabel: "Spectrum Position"
        description: "Where to display the spectrum: bar widget, island dockzone, or both."
        model: ["Bar", "Dockzone", "Both"]
        currentValue: root.mediaSettings ? root.mediaSettings.spectrumPosition : "Bar"
        onSelected: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumPosition",
            value
        )
    }

    SettingDropdown {
        width: parent.width
        settingLabel: "Spectrum Style"
        description: "Choose the audio spectrum visual style."
        model: ["Bars", "Wave", "Dots"]
        currentValue: root.mediaSettings ? root.mediaSettings.spectrumStyle : "Bars"
        onSelected: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumStyle",
            value
        )
    }

    SettingDropdown {
        width: parent.width
        settingLabel: "Spectrum Color"
        description: "Choose the accent color for the spectrum visualization."
        model: ["Primary", "Secondary", "Tertiary"]
        currentValue: root.mediaSettings ? root.mediaSettings.spectrumColor : "Primary"
        onSelected: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumColor",
            value
        )
    }

    SettingSlider {
        width: parent.width
        settingLabel: "Spectrum Opacity"
        description: "Adjust the opacity of the spectrum visualization."
        from: 10
        to: 100
        stepSize: 10
        suffix: "%"
        value: root.mediaSettings ? root.mediaSettings.spectrumOpacity : 34
        onMoved: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumOpacity",
            value
        )
    }

    SettingToggle {
        width: parent.width
        settingLabel: "Spectrum Mirror"
        description: "Mirror the spectrum from the center for a balanced look."
        checked: root.mediaSettings ? root.mediaSettings.spectrumMirror : true
        onToggled: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumMirror",
            value
        )
    }
}
