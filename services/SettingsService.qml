pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Public API: access settings via SettingsService.data.bar.height etc.
    readonly property alias data: adapter

    // Respect XDG_CONFIG_HOME; fall back to ~/.config/dymicshell/
    readonly property string configDir:
        (Quickshell.env("XDG_CONFIG_HOME") !== ""
            ? Quickshell.env("XDG_CONFIG_HOME")
            : Quickshell.env("HOME") + "/.config")
        + "/dymicshell/"
    readonly property string settingsFile: configDir + "settings.json"

    property bool isLoaded: false

    // Emitted once on initial load, after each debounced write, and on hot-reload
    signal settingsLoaded
    signal settingsSaved
    signal settingsReloaded

    Component.onCompleted: {
        // Ensure config directory exists before FileView attempts to read
        Quickshell.execDetached(["mkdir", "-p", configDir])
        settingsFileView.adapter = adapter
    }

    // Batch rapid property writes (e.g. slider drag) into a single disk flush
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            settingsFileView.writeAdapter()
            root.settingsSaved()
        }
    }

    FileView {
        id: settingsFileView
        path: root.settingsFile
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: saveTimer.restart()
        onLoaded: {
            if (!root.isLoaded) {
                root.isLoaded = true
                root.settingsLoaded()
            } else {
                root.settingsReloaded()
            }
        }
        onLoadFailed: function(error) {
            // First run: no settings.json found, write defaults from adapter
            writeAdapter()
        }
    }

    JsonAdapter {
        id: adapter

        property JsonObject appearance: JsonObject {
            property string accentColor:     "#7aa2f7"
            property string backgroundColor: "#1a1a1a"
            property string surfaceColor:    "#252525"
            property string textColor:       "#c0caf5"
            property string textMutedColor:  "#565f89"
            property string borderColor:     "#3b4261"
            property real   cornerRadius:    10
            property real   uiScale:         1.0
            property string fontFamily:      "LXGW WenKai GB Screen"
            property string fontMono:        "JetBrainsMono Nerd Font"
            property int    fontSizeBody:    14
            property int    fontSizeSmall:   10
            property int    fontSizeIcon:    16
        }

        property JsonObject bar: JsonObject {
            property real   height:            36
            property string position:          "top"
            property real   backgroundOpacity: 0.85
            property real   padding:           8
            property real   widgetSpacing:     6
        }

        property JsonObject barBehavior: JsonObject {
            property bool autoHide:      false
            property int  autoHideDelay: 500
            property int  autoShowDelay: 150
        }

        property JsonObject animation: JsonObject {
            property real speedFactor: 1.0
            property int  staggerLevel1BaseDelay: 60
            property int  staggerLevel1Step:      50
            property int  staggerLevel2BaseDelay: 120
            property int  staggerLevel2Step:      50
            property int  staggerExitStep:        15
            property int  staggerEnterDuration:   280
            property int  staggerExitDuration:    100
            property real staggerEnterOffsetY:    30
            property real staggerExitOffsetY:     10
        }
    }
}
