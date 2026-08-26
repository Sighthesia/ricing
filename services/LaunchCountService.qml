pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tracks application launch frequency and recency for launcher ranking.
//
// Persistence uses FileView text + explicit JSON serialization rather than
// JsonAdapter: the maps are dynamic-key dictionaries (entry id -> value),
// which JsonAdapter's fixed declared properties cannot deserialize.
Singleton {
    id: root

    // Map of desktop entry id -> launch count.
    property var counts: ({})

    // Map of desktop entry id -> last launch epoch ms, for recency ranking.
    property var lastAt: ({})

    // First reader may reach this singleton before the async file load
    // lands; force adoption as soon as the load is available so counts are
    // never observed empty merely because of construction timing.
    function _ensureLoaded() {
        if (!root._adopted && launchCountFile.loaded)
            root._adopt(launchCountFile.text())
    }

    function recordLaunch(appId: string) {
        if (!appId) return
        _ensureLoaded()
        var nextCounts = Object.assign({}, counts)
        nextCounts[appId] = (counts[appId] || 0) + 1
        counts = nextCounts
        var nextLast = Object.assign({}, lastAt)
        nextLast[appId] = Date.now()
        lastAt = nextLast
        // Persist immediately: launches are human-scale rare, and a debounced
        // write would lose the last record if the shell exits right after.
        _persist()
    }

    function getLaunchCount(appId: string): int {
        _ensureLoaded()
        return counts[appId] || 0
    }

    // Epoch ms; must stay wider than 32-bit or timestamps truncate.
    function getLastLaunchAt(appId: string): real {
        _ensureLoaded()
        return lastAt[appId] || 0
    }

    function _persist() {
        launchCountFile.setText(JSON.stringify({
            launchCounts: root.counts,
            lastLaunches: root.lastAt
        }))
    }

    function _adopt(text) {
        if (root._adopted)
            return
        root._adopted = true
        if (!text)
            return
        try {
            var parsed = JSON.parse(String(text))
            if (parsed && parsed.launchCounts && typeof parsed.launchCounts === "object")
                root.counts = parsed.launchCounts
            if (parsed && parsed.lastLaunches && typeof parsed.lastLaunches === "object")
                root.lastAt = parsed.lastLaunches
        } catch (err) {
            console.warn("LaunchCountService: unreadable launch-counts.json:", err)
        }
    }

    property bool _adopted: false

    FileView {
        id: launchCountFile
        path: Quickshell.cacheDir + "/launch-counts.json"
        blockLoading: true
        watchChanges: false
        onLoaded: root._adopt(launchCountFile.text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("LaunchCountService: failed to load launch-counts.json:", error)
            root._adopted = true
        }
    }

    Component.onCompleted: {
        // blockLoading usually completes before this runs; adopt now if so,
        // otherwise the onLoaded handler covers the async landing.
        if (launchCountFile.loaded)
            root._adopt(launchCountFile.text())
    }
}
