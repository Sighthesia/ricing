pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Persists per-widget-instance configuration.
// Storage: .state/widget-config.json
// Currently stores widgetConfig (functional) per instanceKey.
// Appearance overrides are planned but not yet implemented.
Singleton {
    id: root

    readonly property string _configDir:  Quickshell.workingDirectory + "/.state"
    readonly property string _configFile: _configDir + "/widget-config.json"

    // In-memory store: instanceKey -> { widgetConfig: {} }
    property var _store: ({})

    Component.onCompleted: fileReader.running = true

    Process {
        id: fileReader
        command: ["cat", root._configFile]
        stdout: SplitParser {
            onRead: function(data) {
                let trimmed = data.trim();
                if (trimmed !== "") {
                    try { root._store = JSON.parse(trimmed); }
                    catch (e) { console.warn("WidgetConfigService: failed to parse widget-config.json:", e); }
                }
            }
        }
    }

    Timer {
        id: _saveTimer
        interval: 500
        repeat: false
        onTriggered: root._flushToDisk()
    }

    Process {
        id: fileWriter
        stdinEnabled: true
        command: ["sh", "-c",
            "mkdir -p '" + root._configDir + "' && cat > '" + root._configFile + "'"]
    }

    function _flushToDisk() {
        fileWriter.running = false;
        fileWriter.running = true;
        fileWriter.write(JSON.stringify(_store, null, 2) + "
");
    }

    // Removes all config for instanceKey (on widget deletion).
    function removeConfig(instanceKey) {
        let store = Object.assign({}, _store);
        delete store[instanceKey];
        _store = store;
        _saveTimer.restart();
    }

    // Returns a portable export object for the given instanceKey.
    function exportPayload(widgetId, instanceKey) {
        let entry = _store[instanceKey] || { widgetConfig: {} };
        return {
            widgetId: widgetId,
            // FIXME: widgetConfig write API not yet implemented
            widgetConfig: entry.widgetConfig || {}
        };
    }
}
