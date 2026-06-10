pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Enumerate system fonts via fc-list for the settings UI font picker.
QtObject {
    id: root

    property ListModel availableFonts: ListModel {}
    property ListModel monospaceFonts: ListModel {}
    property bool fontsLoaded: false
    property bool isLoading: false

    function init() {
        if (fontsLoaded || isLoading)
            return
        loadFonts()
    }

    function loadFonts() {
        if (isLoading)
            return
        isLoading = true
        _allFontsProcess.running = true
    }

    function populateModels(allFontsText, monoFontsText) {
        var monoLookup = {}
        var monoLines = monoFontsText.split('\n')
        for (var i = 0; i < monoLines.length; i++) {
            var line = monoLines[i].trim()
            if (line) {
                var monoFamilies = line.split(',')
                for (var mi = 0; mi < monoFamilies.length; mi++) {
                    var monoName = monoFamilies[mi].trim()
                    if (monoName)
                        monoLookup[monoName] = true
                }
            }
        }

        var allLines = allFontsText.split('\n')
        var fontSet = {}

        for (var j = 0; j < allLines.length; j++) {
            var line = allLines[j].trim()
            if (line) {
                var families = line.split(',')
                for (var fi = 0; fi < families.length; fi++) {
                    var fontName = families[fi].trim()
                    if (fontName && !fontSet[fontName])
                        fontSet[fontName] = true
                }
            }
        }

        var sortedFonts = Object.keys(fontSet).sort(function(a, b) {
            return a.localeCompare(b)
        })

        var allBatch = []
        var monoBatch = []

        for (var k = 0; k < sortedFonts.length; k++) {
            var name = sortedFonts[k]
            var fontObj = { "key": name, "name": name }
            allBatch.push(fontObj)
            if (monoLookup[name] || name.toLowerCase().includes("mono"))
                monoBatch.push(fontObj)
        }

        availableFonts.clear()
        monospaceFonts.clear()

        availableFonts.append({ "key": Qt.application.font.family, "name": "System Default" })
        monospaceFonts.append({ "key": "monospace", "name": "System Default" })

        for (var m = 0; m < allBatch.length; m++)
            availableFonts.append(allBatch[m])
        for (var n = 0; n < monoBatch.length; n++)
            monospaceFonts.append(monoBatch[n])

        fontsLoaded = true
        isLoading = false
    }

    property string _allFontsOutput: ""
    property string _monoFontsOutput: ""
    property bool _allFontsDone: false
    property bool _monoFontsDone: false

    function checkBothProcessesDone() {
        if (_allFontsDone && _monoFontsDone) {
            populateModels(_allFontsOutput, _monoFontsOutput)
            _allFontsOutput = ""
            _monoFontsOutput = ""
            _allFontsDone = false
            _monoFontsDone = false
        }
    }

    property Process _allFontsProcess: Process {
        command: ["fc-list", "--format", "%{family}\\n"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root._allFontsOutput = this.text
                root._allFontsDone = true
                root.checkBothProcessesDone()
            }
        }

        onRunningChanged: {
            if (running)
                root._monoFontsProcess.running = true
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root._allFontsOutput = ""
                root._allFontsDone = true
                root.checkBothProcessesDone()
            }
        }
    }

    property Process _monoFontsProcess: Process {
        command: ["fc-list", ":mono", "--format", "%{family}\\n"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root._monoFontsOutput = this.text
                root._monoFontsDone = true
                root.checkBothProcessesDone()
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root._monoFontsOutput = ""
                root._monoFontsDone = true
                root.checkBothProcessesDone()
            }
        }
    }
}
