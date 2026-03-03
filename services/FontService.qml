pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Lazily loads the system font list via fc-list on first call to init().
// Exposes sorted arrays of font family names suitable for ListView models.
//
// Public API:
//   FontService.init()          — start loading (idempotent)
//   FontService.allFonts        — var[], all font families, sorted
//   FontService.monospaceFonts  — var[], monospace families only, sorted
//   FontService.fontsReady      — bool, true once both processes finish
Singleton {
    id: root

    // Sorted JS arrays of font family name strings.
    property var allFonts: []
    property var monospaceFonts: []
    property bool fontsReady: false

    // Trigger font loading. Safe to call multiple times; only runs once.
    function init() {
        if (fontsReady || allFontsProcess.running || monoFontsProcess.running) return
        _allLines = []
        _monoLines = []
        _allDone = false
        _monoDone = false
        allFontsProcess.running = true
        monoFontsProcess.running = true
    }

    // ── Internal accumulators ──────────────────────────────────────────
    property var _allLines: []
    property var _monoLines: []
    property bool _allDone: false
    property bool _monoDone: false

    function _checkBothDone() {
        if (!_allDone || !_monoDone) return
        _populate(_allLines, _monoLines)
    }

    function _populate(allLines, monoLines) {
        // Build monospace name lookup from fc-list :mono output
        var monoSet = {}
        for (var i = 0; i < monoLines.length; i++) {
            var parts = monoLines[i].split(",")
            for (var p = 0; p < parts.length; p++) {
                var n = parts[p].trim()
                if (n) monoSet[n] = true
            }
        }

        // Collect and deduplicate all font family names
        var fontSet = {}
        for (var j = 0; j < allLines.length; j++) {
            var fparts = allLines[j].split(",")
            for (var q = 0; q < fparts.length; q++) {
                var fn = fparts[q].trim()
                if (fn) fontSet[fn] = true
            }
        }

        var sorted = Object.keys(fontSet).sort(function(a, b) {
            return a.localeCompare(b)
        })

        var allArr = []
        var monoArr = []
        for (var k = 0; k < sorted.length; k++) {
            var name = sorted[k]
            allArr.push(name)
            // Include in mono list if fc-list confirmed it, or name contains "mono"
            if (monoSet[name] || name.toLowerCase().indexOf("mono") !== -1) {
                monoArr.push(name)
            }
        }

        allFonts = allArr
        monospaceFonts = monoArr
        fontsReady = true
    }

    // ── Processes ─────────────────────────────────────────────────────

    // All font families
    Process {
        id: allFontsProcess
        running: false
        command: ["fc-list", "--format", "%{family}\\n"]
        stdout: SplitParser {
            onRead: (data) => {
                var line = data.trim()
                if (line) root._allLines.push(line)
            }
        }
        onRunningChanged: {
            if (!running) {
                root._allDone = true
                root._checkBothDone()
            }
        }
    }

    // Monospace-only families (used to build the mono subset)
    Process {
        id: monoFontsProcess
        running: false
        command: ["fc-list", ":mono", "--format", "%{family}\\n"]
        stdout: SplitParser {
            onRead: (data) => {
                var line = data.trim()
                if (line) root._monoLines.push(line)
            }
        }
        onRunningChanged: {
            if (!running) {
                root._monoDone = true
                root._checkBothDone()
            }
        }
    }
}
