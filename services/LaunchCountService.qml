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

    // Emitted after the on-disk maps have been adopted. Consumers can refresh
    // rankings if they opened during the short initial load window.
    signal persistenceReady()

    // Map of desktop entry id -> launch count.
    property var counts: ({})

    // Map of desktop entry id -> last launch epoch ms, for recency ranking.
    property var lastAt: ({})

    // A launcher action can arrive before FileView finishes its first read.
    // Keep those mutations separate so an early write can never overwrite
    // the persisted maps with the still-empty in-memory defaults.
    property var _pendingCounts: ({})
    property var _pendingLastAt: ({})

    // First reader may reach this singleton before the async file load
    // lands; force adoption as soon as the load is available so counts are
    // never observed empty merely because of construction timing.
    function _ensureLoaded() {
        if (!root._adopted && launchCountFile.loaded)
            root._adopt(launchCountFile.text())
    }

    function _queueLaunch(appId) {
        var nextCounts = Object.assign({}, root._pendingCounts)
        nextCounts[appId] = (nextCounts[appId] || 0) + 1
        root._pendingCounts = nextCounts

        var nextLastAt = Object.assign({}, root._pendingLastAt)
        nextLastAt[appId] = Date.now()
        root._pendingLastAt = nextLastAt
    }

    function _mergePending() {
        var pendingIds = Object.keys(root._pendingCounts)
        if (!pendingIds.length && !Object.keys(root._pendingLastAt).length)
            return false

        var nextCounts = Object.assign({}, root.counts)
        for (var i = 0; i < pendingIds.length; i++) {
            var id = pendingIds[i]
            nextCounts[id] = (nextCounts[id] || 0) + root._pendingCounts[id]
        }
        root.counts = nextCounts

        var nextLastAt = Object.assign({}, root.lastAt, root._pendingLastAt)
        root.lastAt = nextLastAt
        root._pendingCounts = ({})
        root._pendingLastAt = ({})
        return true
    }

    function recordLaunch(appId: string) {
        if (!appId) return
        _ensureLoaded()
        if (!root._adopted) {
            _queueLaunch(appId)
            return
        }
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
        return (counts[appId] || 0) + (root._pendingCounts[appId] || 0)
    }

    // Epoch ms; must stay wider than 32-bit or timestamps truncate.
    function getLastLaunchAt(appId: string): real {
        _ensureLoaded()
        return Math.max(lastAt[appId] || 0, root._pendingLastAt[appId] || 0)
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
        var parsed = {}
        try {
            if (text)
                parsed = JSON.parse(String(text))
        } catch (err) {
            console.warn("LaunchCountService: unreadable launch-counts.json:", err)
            return
        }

        if (parsed && parsed.launchCounts && typeof parsed.launchCounts === "object")
            root.counts = parsed.launchCounts
        if (parsed && parsed.lastLaunches && typeof parsed.lastLaunches === "object")
            root.lastAt = parsed.lastLaunches

        root._adopted = true
        if (root._mergePending())
            root._persist()
        root.persistenceReady()
    }

    property bool _adopted: false

    FileView {
        id: launchCountFile
        path: Quickshell.cacheDir + "/launch-counts.json"
        blockLoading: true
        watchChanges: false
        onLoaded: root._adopt(launchCountFile.text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn("LaunchCountService: failed to load launch-counts.json:", error)
                return
            }
            // A missing file is a valid empty initial state. It is safe to
            // adopt it and flush any launch queued during construction.
            root._adopt("")
        }
    }

    Component.onCompleted: {
        // blockLoading usually completes before this runs; adopt now if so,
        // otherwise the onLoaded handler covers the async landing.
        if (launchCountFile.loaded)
            root._adopt(launchCountFile.text())
    }
}
