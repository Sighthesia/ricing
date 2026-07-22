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

    SettingSlider {
        width: parent.width
        settingLabel: "Spectrum Height"
        description: "Adjust how tall the dockzone spectrum can grow."
        from: 50
        to: 200
        stepSize: 5
        suffix: "%"
        value: root.mediaSettings ? root.mediaSettings.spectrumHeight : 100
        onMoved: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumHeight",
            value
        )
    }

    SettingSlider {
        width: parent.width
        settingLabel: "Max Spectrum Height"
        description: "Cap the maximum height of spectrum bars relative to the bar height."
        from: 20
        to: 100
        stepSize: 5
        suffix: "%"
        value: root.mediaSettings ? root.mediaSettings.spectrumMaxHeight : 100
        onMoved: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumMaxHeight",
            value
        )
    }

    SettingSlider {
        width: parent.width
        settingLabel: "Spectrum Gain"
        description: "Boost quiet audio so bars reach higher at low volume."
        from: 50
        to: 300
        stepSize: 10
        suffix: "%"
        value: root.mediaSettings ? root.mediaSettings.spectrumGain : 100
        onMoved: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumGain",
            value
        )
    }

    SettingSlider {
        width: parent.width
        settingLabel: "Spectrum Bar Width"
        description: "Adjust how wide each spectrum bar can be."
        from: 20
        to: 100
        stepSize: 1
        suffix: "%"
        value: root.mediaSettings ? root.mediaSettings.spectrumBarWidth : 42
        onMoved: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumBarWidth",
            value
        )
    }

    SettingSlider {
        width: parent.width
        settingLabel: "Spectrum Spacing"
        description: "Adjust the gap between spectrum bars."
        from: 0
        to: 12
        stepSize: 1
        suffix: "px"
        value: root.mediaSettings ? root.mediaSettings.spectrumSpacing : 0
        onMoved: value => Services.SettingsService.setWidgetInstanceSettingValue(
            "media",
            root.instanceKey,
            "spectrumSpacing",
            value
        )
    }

}
