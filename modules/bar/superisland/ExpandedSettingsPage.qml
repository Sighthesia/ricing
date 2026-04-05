import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "../settings" as SettingsModule

// Expanded settings page that keeps the full settings content inside SuperIsland.
Item {
    id: root

    function pageActivated() {
        _contentShell.runEnter()
        _enterDelay.restart()
    }

    function pageExitDuration() {
        return SettingsService.data.animation.staggerExitDuration
    }

    function pageDeactivated() {
        _enterDelay.stop()
        _contentShell.runExit()
        if (_settingsContent && _settingsContent.runExitAnimation)
            _settingsContent.runExitAnimation()
    }

    Timer {
        id: _enterDelay
        interval: 180
        repeat: false
        onTriggered: {
            if (_settingsContent && _settingsContent.runEnterAnimation)
                _settingsContent.runEnterAnimation()
        }
    }

    BarComponents.StaggerItem {
        id: _contentShell
        anchors.fill: parent

        SettingsModule.SettingsPanelContent {
            id: _settingsContent
            anchors.fill: parent
        }
    }
}
