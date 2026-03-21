import QtQuick
import qs.services
import "../settings"

Item {
    id: root

    implicitWidth: 296
    implicitHeight: _col.implicitHeight

    Column {
        id: _col
        width: parent.width
        spacing: 0

        ToggleSection {
            width: parent.width
            label: "媒体"
            value: SettingsService.data.superIsland.showMedia
            onToggled: newValue => {
                SettingsService.data.superIsland.showMedia = newValue
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "通知"
            value: SettingsService.data.superIsland.showNotifications
            onToggled: newValue => {
                SettingsService.data.superIsland.showNotifications = newValue
                SettingsService.save()
            }
        }

        ToggleSection {
            width: parent.width
            label: "工作区切换"
            value: SettingsService.data.superIsland.showWorkspaceEvents
            onToggled: newValue => {
                SettingsService.data.superIsland.showWorkspaceEvents = newValue
                SettingsService.save()
            }
        }

        SliderSection {
            width: parent.width
            label: "通知显示时长"
            value: SettingsService.data.superIsland.notificationTimeout
            from: 500; to: 10000; stepSize: 250; unit: "ms"
            onValueCommitted: newValue => {
                SettingsService.data.superIsland.notificationTimeout = newValue
                SettingsService.save()
            }
        }

        SliderSection {
            width: parent.width
            label: "媒体显示时长"
            value: SettingsService.data.superIsland.mediaTimeout
            from: 500; to: 10000; stepSize: 250; unit: "ms"
            onValueCommitted: newValue => {
                SettingsService.data.superIsland.mediaTimeout = newValue
                SettingsService.save()
            }
        }

        SliderSection {
            width: parent.width
            label: "工作区事件显示时长"
            value: SettingsService.data.superIsland.workspaceTimeout
            from: 500; to: 10000; stepSize: 250; unit: "ms"
            onValueCommitted: newValue => {
                SettingsService.data.superIsland.workspaceTimeout = newValue
                SettingsService.save()
            }
        }
    }
}