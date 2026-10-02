import QtQuick
import QtTest

// Structural contract for every `Variants` in the shell: its first child must be
// the per-screen `Scope`.
//
// `Variants.delegate` defaults to the first declared child
// (https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/), so a stray
// object placed above the `Scope` does not get dropped for being the wrong type —
// it becomes the delegate. The per-screen `Scope` is then never instantiated, so
// every window that component owns silently never reaches the compositor, while
// the rest of the shell mounts normally and nothing logs an error.
//
// That is exactly how the wallpaper surface disappeared twice. The first time a
// `Connections` was added above the `Scope` inside `WallpaperBackground.qml`.
// The second time the same `Connections` was added at the *instantiation site*
// in `shell.qml`, where it is still a direct child of the same `Variants` —
// removing the in-file one changed nothing, because the delegate was being
// hijacked from outside the file all along.
//
// So the first-child check below is necessary but not sufficient. An inline
// child at an instantiation site joins the same `data` list, and Quickshell
// hands `modelData` to whichever object ends up as the delegate. Hence
// test_noInstantiationSiteAddsAnInlineChild below.
//
// Static by necessity: `Variants` is a Quickshell *core* type and
// /usr/lib/qt6/qml/Quickshell/qmldir only declares `linktarget
// quickshell-coreplugin`, so qmltestrunner cannot mount any of these files.
// Regenerate `variantsFiles` with
// `rg -l '^[[:space:]]*Variants[[:space:]]*\{' --glob '*.qml'` and
// `instantiationSiteFiles` with
// `rg -l '<TypeName>[[:space:]]*\{' --glob '*.qml'`.
Item {
    id: root

    function readText(path) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl(path), false)
        xhr.send(null)
        return xhr.status === 200 ? xhr.responseText : ""
    }

    readonly property var variantsFiles: [
        "../../modules/bar/TopBar.qml",
        "../../modules/lazerbar/NotificationHost.qml",
        "../../modules/lazerbar/OverviewBackgroundWindow.qml",
        "../../modules/lazerbar/ScreenRoundedCorners.qml",
        "../../modules/lazerbar/TopBar.qml",
        "../../modules/lazerbar/WallpaperBackground.qml"
    ]

    // The same list by type name, which is how an instantiation site names them:
    // `LazerBar.WallpaperBackground { ... }` at shell.qml:362.
    readonly property var delegateTypeNames: {
        var names = []
        for (var index = 0; index < root.variantsFiles.length; index++)
            names.push(root.variantsFiles[index].split("/").pop().replace(/\.qml$/, ""))
        return names
    }

    // Files that instantiate one of the components above. Only these can add an
    // inline child to a `Variants`.
    readonly property var instantiationSiteFiles: [
        "../../shell.qml",
        "../../tst_wallpaper_startup_slots.qml"
    ]

    // Name of the first object declared directly inside this file's `Variants`,
    // or "" when the file declares none. Comments, property assignments and
    // attached-style declarations never match, so the first match in document
    // order is the first child.
    function firstVariantsChild(path) {
        var text = root.readText(path)
        if (!text)
            return ""
        var lines = text.split("\n")
        var inside = false
        for (var index = 0; index < lines.length; index++) {
            var line = lines[index]
            if (!inside) {
                if (/^\s*Variants\s*\{/.test(line))
                    inside = true
                continue
            }
            // The `Variants` is the root object in every one of these files, so
            // its own closing brace is the one at column zero.
            if (/^\}/.test(line))
                return ""
            var match = /^\s*([A-Z][A-Za-z0-9_]*)\s*\{/.exec(line)
            if (match)
                return match[1]
        }
        return ""
    }

    // Same text with string interiors and line comments blanked out, length
    // preserved so offsets still index the original. Brace counting and the
    // declaration regexes then run on this, so a `{` inside `"//"` or a type
    // name inside a comment cannot be read as structure.
    function mask(text) {
        var out = ""
        var inString = false
        var inComment = false
        for (var index = 0; index < text.length; index++) {
            var character = text.charAt(index)
            if (inComment) {
                if (character === "\n")
                    inComment = false
                out += character === "\n" ? "\n" : " "
                continue
            }
            if (inString) {
                if (character === "\\") {
                    out += "  "
                    index++
                    continue
                }
                if (character === "\"")
                    inString = false
                out += character === "\n" ? "\n" : " "
                continue
            }
            if (character === "/" && text.charAt(index + 1) === "/") {
                inComment = true
                out += "  "
                index++
                continue
            }
            if (character === "\"") {
                inString = true
                out += character
                continue
            }
            out += character
        }
        return out
    }

    // End offset of the block whose `{` sits at `open`, or -1 when unbalanced.
    function closingBraceAt(masked, open) {
        var depth = 0
        for (var at = open; at < masked.length; at++) {
            var character = masked.charAt(at)
            if (character === "{")
                depth++
            else if (character === "}" && --depth === 0)
                return at
        }
        return -1
    }

    // Type names of the objects declared *immediately* inside one block. Depth is
    // sampled at the start of each line, so a nested declaration is not counted
    // and a one-liner (`Component { LazerBar.NotificationHost {} }`) contributes
    // only its own outermost type.
    function directObjectChildren(blockMasked) {
        var children = []
        var depth = 0
        var lines = blockMasked.split("\n")
        for (var index = 0; index < lines.length; index++) {
            var line = lines[index]
            if (depth === 1) {
                var match = /^[ \t]*(?:[A-Za-z_][\w]*\.)?([A-Z][A-Za-z0-9_]*)[ \t]*\{/.exec(line)
                if (match)
                    children.push(match[1])
            }
            for (var at = 0; at < line.length; at++) {
                if (line.charAt(at) === "{")
                    depth++
                else if (line.charAt(at) === "}")
                    depth--
            }
        }
        return children
    }

    // Every inline object child added to a `Variants` in one file, as
    // "<type> inside <instantiated type> at line <n>".
    function inlineDelegateHijacks(path) {
        var text = root.readText(path)
        var found = []
        if (!text)
            return found
        var masked = root.mask(text)
        var opener = /(?:[A-Za-z_][\w]*\.)?([A-Z][A-Za-z0-9_]*)[ \t]*\{/g
        var match
        while ((match = opener.exec(masked)) !== null) {
            if (root.delegateTypeNames.indexOf(match[1]) < 0)
                continue
            var open = match.index + match[0].length - 1
            var close = root.closingBraceAt(masked, open)
            if (close < 0)
                continue
            var children = root.directObjectChildren(masked.slice(open, close + 1))
            for (var index = 0; index < children.length; index++) {
                found.push(children[index] + " inside " + match[1] + " at line "
                           + (masked.slice(0, open).split("\n").length))
            }
            opener.lastIndex = close
        }
        return found
    }

    TestCase {
        name: "VariantsDelegate"
        when: windowShown

        function test_everyVariantsTakesAScopeAsItsDelegate() {
            for (var index = 0; index < root.variantsFiles.length; index++) {
                var path = root.variantsFiles[index]
                compare(root.firstVariantsChild(path), "Scope", path
                        + ": the first child of Variants is its delegate, so nothing"
                        + " may be declared above the per-screen Scope")
            }
        }

        // The check that was missing: the first-child rule is about the *data
        // list*, and an instantiation site's inline children land in that same
        // list. This is the assertion that would have caught the live bug — the
        // shell passed test_everyVariantsTakesAScopeAsItsDelegate while the
        // desktop had no wallpaper at all.
        function test_noInstantiationSiteAddsAnInlineChild() {
            for (var index = 0; index < root.instantiationSiteFiles.length; index++) {
                var path = root.instantiationSiteFiles[index]
                var text = root.readText(path)
                verify(text.length > 0, path + ": readable, or this file is a false green")
                compare(root.inlineDelegateHijacks(path).join("; "), "", path
                        + ": a Variants delegate is picked from the instantiation site's"
                        + " inline children too, so declare wiring as siblings of the"
                        + " component, never inside it")
            }
        }

        function test_wallpaperScopeIsTheDelegateAgain() {
            // The component that lost its surfaces, asserted directly so the
            // failure names the surface that went missing.
            verify(root.readText("../../modules/lazerbar/WallpaperBackground.qml")
                   .indexOf('WlrLayershell.namespace: "afloat:wallpaper"') >= 0)
            // And that the shell mounts it with no inline child of its own, which
            // is the shape that silently emptied the desktop.
            verify(root.readText("../../shell.qml")
                   .indexOf("LazerBar.WallpaperBackground {") >= 0)
        }
    }
}
