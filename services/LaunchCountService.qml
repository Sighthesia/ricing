pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tracks application launch counts for frequency-based sorting.
Singleton {
    id: root

    // Map of desktop entry id -> launch count.
    property var counts: ({})

    function recordLaunch(appId: string) {
        if (!appId) return
        counts[appId] = (counts[appId] || 0) + 1
        countsChanged()
        saveTimer.restart()
    }

    function getLaunchCount(appId: string): int {
        return counts[appId] || 0
    }

    // Debounce writes to disk.
    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: launchCountFile.writeAdapter()
    }

    FileView {
        id: launchCountFile
        path: Quickshell.cacheDir + "/launch-counts.json"
        blockLoading: true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                launchCountFile.writeAdapter()
        }

        JsonAdapter {
            id: launchCountAdapter
            property var launchCounts: ({})
        }
    }

    Component.onCompleted: {
        if (launchCountAdapter.launchCounts)
            root.counts = launchCountAdapter.launchCounts
    }

    Connections {
        target: root
        function onCountsChanged() {
            launchCountAdapter.launchCounts = root.counts
        }
    }
}
