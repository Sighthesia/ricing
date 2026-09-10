pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Registry of bundled and user-provided color scheme presets
// (noctalia-shell model). Each preset lives at <Name>/<Name>.json and
// carries the same snake_case schema as the wallpaper colors.json, so
// Color.qml can consume either source through one adapter shape.
Singleton {
    id: root

    // [{ name, path, display }]
    property var schemes: []
    property bool scanning: false

    readonly property string bundledDir: Quickshell.shellDir + "/Assets/ColorScheme"
    readonly property string userDir: {
        const home = Quickshell.env("HOME")
        return (home ? home : Quickshell.workingDirectory) + "/.config/afloat/colorschemes"
    }

    // Display-name special cases (noctalia naming).
    function displayName(schemeName) {
        const name = String(schemeName || "")
        if (name === "Tokyo-Night") return "Tokyo Night"
        if (name === "Rosepine") return "Rose Pine"
        return name
    }

    function schemeByName(name) {
        const wanted = String(name || "")
        for (let i = 0; i < root.schemes.length; i++) {
            if (root.schemes[i].name === wanted)
                return root.schemes[i]
        }
        return null
    }

    function hasScheme(name) {
        return !!root.schemeByName(name)
    }

    // Path for a stored scheme name; empty when unknown.
    function pathFor(name) {
        const entry = root.schemeByName(name)
        return entry ? entry.path : ""
    }

    function rescan() {
        root.scanning = true
        findProcess.command = ["find", "-L", root.bundledDir, root.userDir,
                               "-mindepth", "2", "-name", "*.json", "-type", "f"]
        findProcess.running = false
        findProcess.running = true
    }

    function basename(path) {
        const chunks = String(path || "").split("/")
        const file = chunks[chunks.length - 1]
        return file.replace(/\.json$/, "")
    }

    Process {
        id: findProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const files = this.text.split("\n").filter(function (line) {
                    return line.length > 0
                })
                const seen = {}
                const list = []
                for (let i = 0; i < files.length; i++) {
                    const name = root.basename(files[i])
                    if (!name || seen[name])
                        continue
                    seen[name] = true
                    list.push({ name: name, path: files[i], display: root.displayName(name) })
                }
                list.sort(function (a, b) {
                    return a.display.toLowerCase().localeCompare(b.display.toLowerCase())
                })
                root.schemes = list
                root.scanning = false
            }
        }
    }

    Component.onCompleted: root.rescan()
}
