import Quickshell
import Quickshell.Io
import QtQuick

import "BarLayoutPersistenceOrchestration.js" as PersistenceOrchestrationUtils

// Hosts BarLayoutService disk IO objects so the singleton stays focused on layout state/API.
Item {
    id: root

    required property QtObject serviceRoot

    readonly property string configDir: Quickshell.workingDirectory + "/.state"
    readonly property string configFile: configDir + "/layout.json"
    readonly property alias persistStore: persist
    readonly property alias fileWriterProcess: fileWriter

    function load() {
        PersistenceOrchestrationUtils.runStartupLoad(serviceRoot, persist, fileReader)
    }

    PersistentProperties {
        id: persist
        reloadableId: "barLayoutPersist"
        property string layoutJson: ""
    }

    Process {
        id: fileReader
        command: ["cat", root.configFile]
        stdout: SplitParser {
            onRead: data => PersistenceOrchestrationUtils.applyDiskLayoutChunk(root.serviceRoot, data)
        }
        onRunningChanged: {
            PersistenceOrchestrationUtils.finishDiskRead(root.serviceRoot, running)
        }
    }

    Process {
        id: fileWriter
        stdinEnabled: true
        command: ["sh", "-c", "mkdir -p '" + root.configDir + "' && cat > '" + root.configFile + "'"]
    }
}
