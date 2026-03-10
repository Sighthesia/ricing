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
    }
}