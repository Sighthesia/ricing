pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Own the lock-screen clock placement: probe the runtime once, then compute and
// cache one placement per screen size.
//
// Two things live here rather than in the lock surface.  First, whether the
// Python runtime exists at all -- nothing in QML can know that before asking, so
// a failed import greys out the settings row instead of leaving a toggle that
// silently does nothing.  Second, the scan itself: lock surfaces are created
// when the session locks, and a 1.4s scan started at that moment lands after
// the 800ms entrance wave, so the clock would appear centred and then slide.
// Warming the cache a few seconds after startup, and again after a wallpaper
// change, means the surface finds its placement already waiting.
QtObject {
    id: root

    // False until the probe answers, and forever if the runtime is missing.
    property bool available: false
    property bool probed: false
    // "WIDTHxHEIGHT" -> { path, result }; a different wallpaper on the same
    // screen size is a miss, not a hit.
    property var placements: ({})
    property int revision: 0
    // The scan is a queue of one so several screens take turns.
    property var queue: []
    property var pending: null

    readonly property string scriptPath:
        Quickshell.shellDir + "/scripts/semantic_blank_region.py"
    readonly property bool wanted:
        SettingsService.appearance.lockClockAutoPlacement === true
    readonly property string wallpaperPath:
        String(SettingsService.appearance.wallpaperPath || "")
    readonly property bool ready: root.probed && root.available
    // What the settings row says when the row is greyed out.
    readonly property string hint: probed
        ? Services.Tr.q("settings.lockClockAutoPlacement.hint")
        : Services.Tr.q("settings.lockClockAutoPlacement.probing")

    // The clock footprint on screen plus room to breathe, from the same scan
    // the design-time tool runs.
    readonly property string clockShape: "0.22x0.16"
    readonly property real margin: 0.06

    signal placementChanged()

    function key(width, height) {
        return Number(width) + "x" + Number(height)
    }

    // A cached placement for this screen and wallpaper, or null while one is
    // being computed.  Reads `revision` so a binding to it re-evaluates on
    // arrival.
    function placement(width, height, path) {
        root.revision
        var entry = root.placements[root.key(width, height)]
        if (!entry || entry.path !== String(path || ""))
            return null
        return entry.result
    }

    function request(width, height, path): void {
        var file = String(path || root.wallpaperPath)
        if (!root.ready || !root.wanted || file === "")
            return
        if (!(width > 0) || !(height > 0))
            return
        var id = root.key(width, height)
        if (root.placement(width, height, file) !== null)
            return
        if (root.pending !== null && root.pending.id === id && root.pending.path === file)
            return
        for (var i = 0; i < root.queue.length; i++) {
            if (root.queue[i].id === id && root.queue[i].path === file)
                return
        }
        root.queue = root.queue.concat([{ id: id, path: file }])
        _pump()
    }

    function _pump(): void {
        if (worker.running || root.queue.length === 0)
            return
        var job = root.queue[0]
        root.queue = root.queue.slice(1)
        var parts = job.id.split("x")
        root.pending = job
        worker.command = [
            "nice", "-n", "19",
            "python3", root.scriptPath,
            "--image", job.path,
            "--screen-width", parts[0],
            "--screen-height", parts[1],
            "--clock", root.clockShape,
            "--margin", String(root.margin),
        ]
        worker.running = true
    }

    function _apply(job, raw): void {
        var result = null
        try {
            result = JSON.parse(String(raw || "").trim())
        } catch (error) {
            console.warn("ClockPlacementService: invalid analyzer output", error)
            return
        }
        if (!result || result.ok !== true)
            return
        var next = Object.assign({}, root.placements)
        next[job.id] = { path: job.path, result: result }
        root.placements = next
        root.revision += 1
        root.placementChanged()
    }

    function probe(): void {
        if (probeProcess.running)
            return
        probeProcess.running = true
    }

    Component.onCompleted: probe()

    // Warm the cache once the desktop has settled.  The scan is ~1.4s of CPU at
    // nice 19; starting it during the wallpaper reveal starves the render
    // thread, and a lock is minutes away, never seconds.
    onWantedChanged: if (root.wanted) warmup.restart()
    onWallpaperPathChanged: if (root.wanted) warmup.restart()

    property Timer warmup: Timer {
        interval: 5000
        repeat: false
        running: true
        onTriggered: {
            var screens = Quickshell.screens || []
            for (var i = 0; i < screens.length; i++) {
                var screen = screens[i]
                if (screen && screen.width > 0 && screen.height > 0) {
                    root.request(screen.width, screen.height, root.wallpaperPath)
                }
            }
        }
    }

    // One interpreter, one import line, no scan: this has to stay cheaper than
    // the wallpaper reveal it competes with at startup.  Declared as a property
    // because QtObject has no default property to hold a child object.
    property Process probeProcess: Process {
        command: ["python3", "-c", "import cv2, numpy"]
        onExited: function(code, status) {
            root.probed = true
            root.available = code === 0
            if (!root.available) {
                console.info("ClockPlacementService: python3 cannot import cv2/numpy; "
                             + "the lock clock stays centred")
            } else {
                warmup.restart()
            }
        }
    }

    property Process worker: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.pending !== null)
                    root._apply(root.pending, this.text)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var message = this.text.trim()
                if (message)
                    console.warn("ClockPlacementService:", message)
            }
        }
        onExited: {
            root.pending = null
            root._pump()
        }
    }
}
