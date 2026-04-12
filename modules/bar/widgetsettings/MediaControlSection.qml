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
            label: "Cava 可视化"
            value: SettingsService.data.mediaControl.cavaEnabled
            onToggled: newValue => {
                SettingsService.data.mediaControl.cavaEnabled = newValue
                SettingsService.save()
            }
        }
    }
}
