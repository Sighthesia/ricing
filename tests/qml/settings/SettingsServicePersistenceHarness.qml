import Quickshell.Io
import QtQuick
import qs.services

// Regression harness for settings persistence through SettingsService.save().
Item {
    id: root

    property bool _saveCallThrew: false
    property bool _verificationReady: false
    property string _loadedText: ""

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _startSaveScenario() {
        SettingsService.data.workspaceWidget.defaultMode = "overview"

        try {
            SettingsService.save()
        } catch (error) {
            root._saveCallThrew = true
        }

        _verifyTimer.restart()
    }

    function _assertSavedFile() {
        root._assert(!root._saveCallThrew, "SettingsService.save() should exist and not throw")
        root._assert(root._loadedText.indexOf('"defaultMode": "overview"') !== -1,
            "saved settings file should contain the updated workspaceWidget.defaultMode")
        Qt.quit()
    }

    Component.onCompleted: {
        if (SettingsService.isLoaded)
            _startTimer.restart()
    }

    Timer {
        id: _startTimer
        interval: 150
        repeat: false
        onTriggered: root._startSaveScenario()
    }

    Connections {
        target: SettingsService
        function onSettingsLoaded() {
            _startTimer.restart()
        }
    }

    Timer {
        id: _verifyTimer
        interval: 4000
        repeat: false
        onTriggered: {
            root._verificationReady = true
        }
    }

    Loader {
        id: _verificationLoader
        active: root._verificationReady
        sourceComponent: _verificationViewComponent
    }

    Component {
        id: _verificationViewComponent

        FileView {
            path: SettingsService.settingsFile
            onLoaded: {
                root._loadedText = text()
                root._assertSavedFile()
            }
            onLoadFailed: {
                throw new Error("saved settings file should be readable after save")
            }
        }
    }
}
