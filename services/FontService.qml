pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Enumerate system fonts via fc-list for the settings UI font picker.
// The singleton is created on first reference and populates itself from
// Component.onCompleted, so the fc-list scans only run once a surface that
// needs a font list (the appearance settings page) actually loads.
QtObject {
    id: root

    property ListModel availableFonts: ListModel {}
    property ListModel monospaceFonts: ListModel {}
    // Plain-array mirrors of the two models, in the shape the settings
    // dropdown consumes: [{ value, label }]. The leading entry of each list
    // has an empty value, which means "follow the system default"; its label
    // is a placeholder the caller localizes. Read-only to consumers; the
    // mutable backings below are what populateModels() writes.
    property var _availableFontList: []
    property var _monospaceFontList: []
    readonly property var availableFontList: root._availableFontList
    readonly property var monospaceFontList: root._monospaceFontList
    property bool fontsLoaded: false
    property bool isLoading: false

    Component.onCompleted: root.init()

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

        root._availableFontList = root._fontChoices(allBatch)
        root._monospaceFontList = root._fontChoices(monoBatch)

        fontsLoaded = true
        isLoading = false
    }

    // Dropdown model for one font batch: the "follow system" entry first,
    // then the families in the order fc-list reported them.
    function _fontChoices(batch) {
        var choices = [{ value: "", label: "Follow system" }]
        for (var i = 0; i < batch.length; i++)
            choices.push({ value: batch[i].name, label: batch[i].name })
        return choices
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
