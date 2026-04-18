import QtQuick
import qs.services
import "../settings"

// Widget-settings section for media control behavior and visualizer options.
Item {
    id: root

    implicitWidth: ThemeSettings.rowWidth
    implicitHeight: _col.implicitHeight

    Column {
        id: _col
        width: parent.width
        spacing: 0

        ToggleSection {
            width: parent.width
            label: "启用"
            value: SettingsService.data.mediaControl.enabled
            onToggled: newValue => {
                SettingsService.data.mediaControl.enabled = newValue
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "空闲时显示"
            value: SettingsService.data.mediaControl.showWhenIdle
            onToggled: newValue => {
                SettingsService.data.mediaControl.showWhenIdle = newValue
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "媒体事件展开 Flash"
            value: SettingsService.data.mediaControl.announcementEnabled
            onToggled: newValue => {
                SettingsService.data.mediaControl.announcementEnabled = newValue
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "悬浮展开控制条"
            value: SettingsService.data.mediaControl.hoverRevealControls
            onToggled: newValue => {
                SettingsService.data.mediaControl.hoverRevealControls = newValue
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "显示歌词"
            value: SettingsService.data.mediaControl.showLyrics
            onToggled: newValue => {
                SettingsService.data.mediaControl.showLyrics = newValue
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "优先显示歌词"
            value: SettingsService.data.mediaControl.preferLyrics
            enabled: SettingsService.data.mediaControl.showLyrics
            onToggled: newValue => {
                SettingsService.data.mediaControl.preferLyrics = newValue
                SettingsService.save()
            }
        }

        SegmentedSection {
            width: parent.width
            label: "歌词优先显示"
            currentValue: SettingsService.data.mediaControl.lyricsPrimarySource
            options: [
                { value: "original", label: "原始歌词" },
                { value: "translated", label: "翻译歌词" }
            ]
            shown: SettingsService.data.mediaControl.showLyrics && SettingsService.data.mediaControl.preferLyrics
            onOptionSelected: value => {
                SettingsService.data.mediaControl.lyricsPrimarySource = value
                SettingsService.save()
            }
        }

        SliderSection {
            width: parent.width
            label: "紧凑最大宽度"
            value: SettingsService.data.mediaControl.compactTextMaxWidth
            from: 100; to: 320; stepSize: 10; unit: "px"
            onValueCommitted: newValue => {
                SettingsService.data.mediaControl.compactTextMaxWidth = newValue
                SettingsService.save()
            }
        }

        // Keep compact media text behavior configurable for long titles and lyrics.
        SegmentedSection {
            width: parent.width
            label: "长文本处理"
            currentValue: SettingsService.data.mediaControl.compactTextOverflowMode
            options: [
                { value: "elide", label: "省略" },
                { value: "scroll", label: "滚动" }
            ]
            onOptionSelected: value => {
                SettingsService.data.mediaControl.compactTextOverflowMode = value
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "Cava 可视化"
            value: SettingsService.data.mediaControl.cavaEnabled
            onToggled: newValue => {
                SettingsService.data.mediaControl.cavaEnabled = newValue
                SettingsService.save()
            }
        }
    }
}
