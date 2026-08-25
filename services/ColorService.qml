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

    // Debounce rapid wallpaper changes
    property string _pendingPath: ""

    function extractColors(wallpaperPath) {
        if (!wallpaperPath) return
        _pendingPath = wallpaperPath
        _debounce.restart()
    }

    function commandFor(wallpaperPath, outputPath, mode, scheme) {
        const modeFlag = mode === "dark" ? " --dark" : mode === "light" ? " --light" : ""
        const scriptPath = Quickshell.shellDir + "/scripts/theming/template-processor.py"
        return 'mkdir -p "' + Quickshell.cacheDir + '" && python3 "' + scriptPath
                + '" "' + wallpaperPath + '"' + modeFlag
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
            jobs += 'python3 "' + scriptPath + '" "' + wallpaperPath
                    + '" --scheme-type ' + s + ' -o "' + dir + '/' + s + '.json" & '
        }
        return 'mkdir -p "' + dir + '" && rm -f "' + dir + '"/*.json && ('
                + jobs + 'wait) && python3 "' + mergeScript + '" "' + dir + '" "' + merged + '"'
    }

    // Refresh the cached palette once at startup so a fresh shell always
    // matches the current wallpaper without waiting for a wallpaper change.
    Component.onCompleted: extractColors(Services.SettingsService.appearance.wallpaperPath)

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

    property Timer _debounce: Timer {
        interval: 150
        onTriggered: {
            if (extractProcess.running) {
                extractProcess.running = false
            } else {
                root._execute()
            }
        }
    }

    function _execute() {
        if (!_pendingPath) return
        var outputPath = Quickshell.cacheDir + "/colors.json"
        var cmd = commandFor(_pendingPath, outputPath, requestedMode)
        _pendingPath = ""
        extractProcess.command = ["sh", "-c", cmd]
        isExtracting = true
        extractProcess.running = true
    }

    property Process _proc: Process {
        id: extractProcess
        running: false

        onExited: function(exitCode, exitStatus) {
            root.isExtracting = false
            root.pendingScheme = ""
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
