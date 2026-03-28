import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings" as SettingsModule

// Expanded settings page that keeps the full settings content inside SuperIsland.
Item {
    id: root

    function pageActivated() {
        _enterDelay.restart()
    }

    function pageDeactivated() {
        _enterDelay.stop()
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

    SettingsModule.SettingsPanelContent {
        id: _settingsContent
        anchors.fill: parent
    }
}
