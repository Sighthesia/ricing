pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Invoke Python color extraction from wallpaper images, writing results to colors.json.
QtObject {
    id: root

    property bool isExtracting: false
    // True while the per-scheme preview batch for the settings panel runs.
    property bool isPreviewing: false
    readonly property var schemeTypes: [
        "tonal-spot", "content", "fruit-salad", "rainbow",
        "monochrome", "vibrant", "faithful", "muted",
    ]
    readonly property string requestedScheme: {
        const value = String(Services.SettingsService.appearance.themeScheme || "tonal-spot")
        return schemeTypes.indexOf(value) >= 0 ? value : "tonal-spot"
    }
    readonly property string requestedMode: {
        const value = String(Services.SettingsService.appearance.colorScheme || "auto")
        return value === "dark" || value === "light" ? value : "auto"
    }

    // Palette extraction is a ~1.6s CPU-bound Python job, and the wallpaper
    // reveal animates a full-screen surface. Running the job inside that window
    // starves the render thread and stalls the transition, so requests are held
    // until the reveal reports it finished (see revealStarted/revealCompleted,
    // called by the wallpaper window). The hold timer flushes regardless, so a
    // missed signal can never leave the theme stale.
    readonly property string _lowPriority: "nice -n 19"
    // The reveal gate above only covers the wallpaper window. The startup
    // window is wider than that — the locked floor, the wallpaper reveal and
    // chrome staging all overlap here — and Component.onCompleted asks for the
    // current wallpaper on the very first turn, which is the locked floor. So
    // extraction has a second, coarser gate in front of the reveal one: while it
    // is closed a request is only recorded, never started. One-way: the shell
    // opens it once the startup queue finishes, and it never closes again, so
    // every later wallpaper switch takes the ordinary reveal-gated path.
    property bool _startupQuiet: false
    property bool _revealInFlight: false
    property string _heldPath: ""
    // Path currently owned by the extraction process. When a reveal starts
    // while that process is active, it is moved back into the deferred queue
    // before the process is stopped.
    property string _runningPath: ""
    // Process.running can remain true until the exit signal is delivered. Keep
    // the reveal interruption explicit so that late onExited cannot restart a
    // queued extraction while the transition is still in flight.
    property bool _processStopRequested: false

    // Debounce rapid wallpaper changes. `delay` overrides the coalescing window.
    property string _pendingPath: ""

    // A restart usually re-extracts a palette that is already cached, which is
    // a ~1.6s CPU-bound job for no gain. The extractor stamps colors.json with
    // its source, so a matching stamp means the cached palette is still the
    // right one and the job can be skipped. Only an in-place edit of the
    // wallpaper file (same path, new pixels, shell not running) is missed;
    // changing the wallpaper through the shell always changes the path.
    property FileView _paletteFile: FileView {
        path: Quickshell.cacheDir + "/colors.json"
        preload: true
        blockLoading: true
        printErrors: false
    }

    function _cacheCovers(wallpaperPath) {
        var raw = _paletteFile.text()
        if (raw === "")
            return false
        try {
            var source = JSON.parse(raw).source
            return !!source
                && String(source.path || "") === String(wallpaperPath)
                && String(source.scheme || "") === String(requestedScheme)
        } catch (error) {
            return false
        }
    }

    function extractColors(wallpaperPath, delay) {
        if (!wallpaperPath) return
        if (_cacheCovers(wallpaperPath)) {
            _pendingPath = ""
            return
        }
        _pendingPath = wallpaperPath
        // Startup gate: keep the newest request and start nothing. Checked before
        // the reveal branch on purpose — a request parked in the held slot is
        // flushed by revealCompleted(), and that flush must respect the same
        // gate, so the pending slot is where a startup request belongs until the
        // shell opens it.
        if (!root._startupQuiet)
            return
        if (_revealInFlight) {
            _heldPath = wallpaperPath
            _pendingPath = ""
            _debounce.stop()
            return
        }
        _debounce.interval = delay ? Math.max(0, Number(delay)) : 500
        _debounce.restart()
    }

    // Open the startup gate. Idempotent by construction: the early return is what
    // makes the gate one-way, so a duplicated startup report cannot arm a second
    // extraction, and only a request that was actually recorded is flushed. A
    // palette that is already cached leaves nothing pending and starts nothing.
    function startupQuietReady() {
        if (root._startupQuiet)
            return
        root._startupQuiet = true
        if (!root._pendingPath)
            return
        root._debounce.interval = 120
        root._debounce.restart()
    }

    // Move a request that has not started yet into the reveal-held slot. The
    // running path is the fallback when the process itself has to be stopped.
    function _holdCurrentRequest() {
        if (_pendingPath) {
            _heldPath = _pendingPath
            _pendingPath = ""
        } else if (!_heldPath && _runningPath) {
            _heldPath = _runningPath
        }
    }

    // Announced by the wallpaper window: a reveal is about to animate the
    // screen, so palette work waits.
    function revealStarted() {
        _revealInFlight = true
        _debounce.stop()
        _holdCurrentRequest()
        // A boot extraction can already be running when the asynchronously
        // decoded image becomes ready. Leaving it alive still competes with
        // the full-screen mask, so stop it and replay its path after the reveal.
        if (_proc.running) {
            _processStopRequested = true
            _proc.running = false
        }
        _holdTimer.restart()
    }

    // The reveal is done, or never ran; flush a held request right away.
    function revealCompleted() {
        if (!_revealInFlight)
            return
        _revealInFlight = false
        _holdTimer.stop()
        if (_heldPath) {
            _pendingPath = _heldPath
            _heldPath = ""
            // A reveal that ends inside the startup window hands the request back
            // but must not start it; startupQuietReady() flushes it instead.
            if (!root._startupQuiet)
                return
            _debounce.interval = 120
            _debounce.restart()
        }
    }

    function commandFor(wallpaperPath, outputPath, mode, scheme) {
        // colors.json 始终写双模式：opencode/herdr 等双变体模板需要同时
        // 引用 dark/light，单模式回退只能复制当前值。双模式额外开销仅为
        // 一次 generate_theme，明暗翻转无需重新提取。
        const scriptPath = Quickshell.shellDir + "/scripts/theming/template-processor.py"
        return 'mkdir -p "' + Quickshell.cacheDir + '" && ' + root._lowPriority
                + ' python3 "' + scriptPath
                + '" "' + wallpaperPath + '" --both'
                + ' --scheme-type ' + (scheme || requestedScheme)
                + ' -o "' + outputPath + '"'
    }

    // One parallel run per scheme type, then a merged previews JSON the
    // settings panel watches. Preview themes always cover both modes.
    function previewCommandFor(wallpaperPath) {
        const scriptPath = Quickshell.shellDir + "/scripts/theming/template-processor.py"
        const mergeScript = Quickshell.shellDir + "/scripts/theming/merge_previews.py"
        const dir = Quickshell.cacheDir + "/theme-previews"
        const merged = Quickshell.cacheDir + "/theme-previews.json"
        let jobs = ''
        for (let i = 0; i < schemeTypes.length; i++) {
            const s = schemeTypes[i]
            jobs += root._lowPriority + ' python3 "' + scriptPath + '" "' + wallpaperPath
                    + '" --scheme-type ' + s + ' -o "' + dir + '/' + s + '.json" & '
        }
        return 'mkdir -p "' + dir + '" && rm -f "' + dir + '"/*.json && ('
                + jobs + 'wait) && ' + root._lowPriority + ' python3 "' + mergeScript
                + '" "' + dir + '" "' + merged + '"'
    }

    // Refresh the cached palette once at startup so a fresh shell always
    // matches the current wallpaper without waiting for a wallpaper change.
    // This runs on the locked floor, so the startup gate is what defers it now;
    // it records the path and the shell's startup queue opens the gate, which
    // restarts the debounce itself. The delay only still covers a request that
    // arrives after the gate and before the wallpaper window starts its reveal.
    Component.onCompleted: extractColors(Services.SettingsService.appearance.wallpaperPath, 900)

    // Regenerate palettes whenever the requested scheme or template changes.
    // A template/mode switch is served from the preview cache when fresh, so
    // switching feels instant; the script only runs on a cache miss.
    property Connections _schemeConnection: Connections {
        target: Services.SettingsService.appearance
        function onColorSchemeChanged() {
            root.applyScheme(Services.SettingsService.appearance.wallpaperPath)
        }
        function onThemeSchemeChanged() {
            root.applyScheme(Services.SettingsService.appearance.wallpaperPath)
        }
    }

    // Run the per-scheme preview batch so the theme template cards show the
    // current wallpaper's palettes. Triggered from the settings overlay open.
    property string _lastPreviewKey: ""
    // Scheme awaiting a script-driven extraction; drives the card busy state.
    property string pendingScheme: ""

    // Merged per-scheme themes written by previewSchemes().
    property var previewsData: null
    property FileView _previewFile: FileView {
        path: Quickshell.cacheDir + "/theme-previews.json"
        watchChanges: false
        printErrors: false
        onLoaded: root.previewsData = root._parse(text())
        onLoadFailed: root.previewsData = null
    }

    function _parse(raw) {
        try { return JSON.parse(raw) } catch (e) { return null }
    }

    function previewSchemes() {
        const path = Services.SettingsService.appearance.wallpaperPath
        if (!path || isPreviewing) return
        if (path === _lastPreviewKey) return
        _lastPreviewKey = path
        previewProcess.command = ["sh", "-c", previewCommandFor(path)]
        isPreviewing = true
        previewProcess.running = true
    }

    // Serve a template/mode switch from the cached previews when they belong
    // to the current wallpaper; otherwise fall back to the extraction script.
    function applyScheme(path) {
        if (!path) return
        if (path === _lastPreviewKey && applyFromPreviews(requestedScheme)) {
            pendingScheme = ""
            return
        }
        pendingScheme = requestedScheme
        extractColors(path)
    }

    // Write colors.json straight from the merged preview data. Returns true
    // when the palette was available and the file was updated.
    function applyFromPreviews(scheme) {
        const data = previewsData ? previewsData[scheme] : null
        if (!data || !data.dark || !data.light) return false
        _colorsWriter.setText(JSON.stringify({ "dark": data.dark, "light": data.light }))
        return true
    }

    // Dedicated writer for colors.json; atomic by default so the watcher in
    // Color.qml always reads a complete palette.
    property FileView _colorsWriter: FileView {
        path: Quickshell.cacheDir + "/colors.json"
        watchChanges: false
        printErrors: false
    }

    // Safety net for a held request: a reveal that never reports completion
    // (surface unmapped, image error, interrupted switch) must not wedge the
    // palette.
    property Timer _holdTimer: Timer {
        interval: 1500
        onTriggered: root.revealCompleted()
    }

    // Coalesces rapid wallpaper/scheme changes into one extraction run.
    property Timer _debounce: Timer {
        interval: 500
        onTriggered: {
            if (root._revealInFlight) {
                root._holdCurrentRequest()
                return
            }
            // A stopped process is still draining its exit signal. Do not reuse
            // this Process until onExited has acknowledged that stop, otherwise
            // the old callback can clear the new run's path and busy state.
            if (root._processStopRequested)
                return
            if (extractProcess.running) {
                extractProcess.running = false
            } else {
                root._execute()
            }
        }
    }

    // The single place a Process is started, so the startup gate is enforced here
    // rather than at every caller: nothing can reach a shell before the gate, and
    // a caller that forgot to check still cannot start work during startup.
    function _execute() {
        if (!root._startupQuiet)
            return
        if (_revealInFlight) {
            _holdCurrentRequest()
            return
        }
        if (!_pendingPath) return
        var outputPath = Quickshell.cacheDir + "/colors.json"
        var cmd = commandFor(_pendingPath, outputPath, requestedMode)
        _runningPath = _pendingPath
        _processStopRequested = false
        _pendingPath = ""
        extractProcess.command = ["sh", "-c", cmd]
        isExtracting = true
        extractProcess.running = true
    }

    property Process _proc: Process {
        id: extractProcess
        running: false

        onExited: function(exitCode, exitStatus) {
            var stoppedForReveal = root._processStopRequested
            root._processStopRequested = false
            root.isExtracting = false
            root.pendingScheme = ""
            root._runningPath = ""
            if (root._revealInFlight || stoppedForReveal) {
                // If the reveal ended before the process delivered onExited,
                // make sure the deferred request still gets another attempt.
                if (!root._revealInFlight && root._pendingPath) {
                    root._debounce.interval = 120
                    root._debounce.restart()
                }
                return
            }
            if (root._pendingPath) {
                root._execute()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (text) console.warn("ColorService:", text)
            }
        }
    }

    property Process _previewProc: Process {
        id: previewProcess
        running: false

        onExited: function(exitCode, exitStatus) {
            root.isPreviewing = false
            if (exitCode !== 0) {
                root._lastPreviewKey = ""
            } else {
                // Refresh the parsed cache so template switches can be served
                // without rerunning the extraction script.
                root._previewFile.reload()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (text) console.warn("ColorService previews:", text)
            }
        }
    }
}
