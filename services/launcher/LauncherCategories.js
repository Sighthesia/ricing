.pragma library

// Launcher category taxonomy: assigns one category id to every pooled
// result and shapes the filter chips that narrow the list by it.
//
// Three independent classifiers feed the same chip bar:
//   - apps: the freedesktop .desktop Categories list mapped onto a small
//     bucket set (an entry may declare many; a fixed bucket precedence
//     picks the single id that owns it);
//   - clipboard: content heuristics over the stored preview (image / link /
//     color / number / code / plain text), so no user tagging is needed;
//   - shortcuts: the niri bind category the parser already assigns, which
//     rides the generic "id outside the taxonomy" path.
//
// Pure JavaScript with no imports so tests exercise the exact module the
// production launcher wires in.

// Chip id of the unfiltered entry; "" is the session's "no lens" value.
var allId = ""

// ---- Shared helpers ----

function normalizeText(value) {
    return value == null ? "" : String(value).replace(/\s+/g, " ").trim()
}

function hasKey(map, key) {
    return Object.prototype.hasOwnProperty.call(map, key)
}

// Keys are prefixed so an id can never collide with an Object prototype
// member ("constructor", "toString") while counting.
function countKey(id) {
    return "$" + id
}

function indexOfId(list, id) {
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id)
            return i
    return -1
}

function normalizeCategoryList(value) {
    if (!value || typeof value.length !== "number")
        return []
    var out = []
    for (var i = 0; i < value.length; i++) {
        var token = normalizeText(value[i]).toLowerCase()
        if (token.length > 0)
            out.push(token)
    }
    return out
}

// ---- Applications ----

// Bucket precedence, most specific first. An entry listing both Game and
// Utility belongs to Games, a Development-tooling entry beats Utility, and
// "other" is the terminal bucket that matches nothing (it is reached only
// as the fallback, never through its empty pattern lists).
//
// `exact` matches whole freedesktop values, `prefixes` matches value
// families ("Game" also covers ActionGame, ArcadeGame, ...).
var appBuckets = [
    {
        id: "games",
        label: "Games",
        exact: ["game", "shooter", "roleplaying", "amusement", "emulator"],
        prefixes: ["game"]
    },
    {
        id: "dev",
        label: "Dev",
        exact: ["development", "ide", "debugger", "profiling", "revisioncontrol",
                "guidemaker", "guidesigner", "building", "coding", "sdk",
                "terminalemulator"],
        prefixes: ["development"]
    },
    {
        id: "graphics",
        label: "Graphics",
        exact: ["graphics", "photography", "scanning", "screenshooter",
                "imageprocessing", "2dgraphics", "3dgraphics", "rastegraphics",
                "vectorgraphics", "cad", "chart", "datavisualization",
                "vector", "raster", "modeling"],
        prefixes: ["graphics"]
    },
    {
        id: "media",
        label: "Media",
        exact: ["audiovideo", "audio", "video", "music", "player", "tv",
                "discburning", "midi", "mixer", "sequencer", "recording",
                "tuner", "television", "photocapture"],
        prefixes: ["audio", "video"]
    },
    {
        id: "network",
        label: "Network",
        exact: ["network", "webbrowser", "telephony", "telephonytools", "chat",
                "instantmessaging", "messaging", "email", "contactmanagement",
                "p2p", "remoteaccess", "remotedesktop", "ftp", "videoconference",
                "hamradio", "irc", "web"],
        prefixes: ["network", "web"]
    },
    {
        id: "office",
        label: "Office",
        exact: ["office", "wordprocessor", "spreadsheet", "presentation",
                "publisher", "flowoffice", "calendar", "finance", "dictionary",
                "texttools", "ocr", "translation", "documentation",
                "projectmanagement", "news", "publishing", "chart2d",
                "flowchart", "groupware"],
        prefixes: ["office"]
    },
    {
        id: "system",
        label: "System",
        exact: ["system", "filesystem", "filesystems", "security", "accessibility",
                "desktopsettings", "display", "displaysettings", "keyboard",
                "mouse", "printing", "packagemanager", "applet", "preferences",
                "monitor", "monitoring"],
        prefixes: ["system", "desktop", "display"]
    },
    {
        id: "utility",
        label: "Utilities",
        exact: ["utility", "utilities", "calculator", "compression", "archive",
                "benchmark", "education", "engineering", "medical", "physics",
                "math", "numericalanalysis", "astronomy", "biology", "chemistry",
                "geography", "geology", "geophysics", "history", "humanities",
                "literature", "maps", "sports", "parallelcomputing",
                "electronics", "economics", "economy", "robotics", "spirituality",
                "adult", "core", "kde", "gnome", "xfce", "java", "sane"],
        prefixes: ["science", "utility"]
    },
    {
        id: "other",
        label: "Other",
        exact: [],
        prefixes: []
    }
]

// pass 0 asks for an exact freedesktop name, pass 1 for a family prefix.
function bucketMatches(bucket, token, pass) {
    if (pass === 0) {
        var exact = bucket.exact || []
        for (var i = 0; i < exact.length; i++)
            if (exact[i] === token)
                return true
        return false
    }
    var prefixes = bucket.prefixes || []
    for (var p = 0; p < prefixes.length; p++) {
        // Freedesktop spells families in both directions: "Game" heads
        // ActionGame but is itself spelled out, so a family is a leading or
        // a trailing segment - never a loose substring, or "Video" would
        // match the Development bucket's "IDE".
        var family = prefixes[p]
        if (token.indexOf(family) === 0
                || (token.length > family.length
                    && token.lastIndexOf(family) === token.length - family.length))
            return true
    }
    return false
}

// Category id of one desktop entry. Two passes: an exact freedesktop name
// is unambiguous, so it wins anywhere in the taxonomy, and only then do the
// family prefixes decide - which is what keeps "VideoConference" out of the
// Media bucket's "video" family and "ActionGame" inside Games.
function appCategoryOf(entry) {
    var tokens = normalizeCategoryList(entry ? entry.categories : null)
    if (!tokens.length)
        return "other"
    for (var pass = 0; pass < 2; pass++) {
        for (var b = 0; b < appBuckets.length; b++) {
            var bucket = appBuckets[b]
            if (!bucket.exact.length && !bucket.prefixes.length)
                continue
            for (var t = 0; t < tokens.length; t++)
                if (bucketMatches(bucket, tokens[t], pass))
                    return bucket.id
        }
    }
    return "other"
}

// ---- Clipboard ----

var clipboardTaxonomy = [
    { id: "text", label: "Text" },
    { id: "link", label: "Links" },
    { id: "code", label: "Code" },
    { id: "image", label: "Images" },
    { id: "color", label: "Colors" },
    { id: "number", label: "Numbers" }
]

var linkPattern = /^(?:https?|ftps?|file|ssh|git|mailto|irc|ircs|magnet|news|nntp):\S+$|^www\.[^\s/]+\.\S{2,}$/i
var colorPattern = /^#(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i
var functionalColorPattern = /^(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch)\(\s*[-\w.%/,\s]+\)$/i
var numberPattern = /^[+-]?(?:\d{1,3}(?:[ ,]\d{3})+|\d+)(?:\.\d+)?(?:[eE][+-]?\d+)?(?:\s?(?:%|°[CF]?|px|pt|pc|em|rem|vh|vw|vmin|vmax|mm|cm|in|ms|s|h|d|[KMGTPE]i?B|[kmgtpe]b))?$/
// Declaration / pragma / markup openers: shapes prose never produces.
var codeLinePattern = /^\s*(?:#!|#include\b|#define\b|#pragma\b|@[A-Za-z_][\w.]*\s*\(|\/\*|def\s+\w+\s*[(!:]|class\s+\w+\s*[(!:{]|function\s*[\w$]*\s*\(|import\s+[\w.$*{"']|from\s+[\w.]+\s+import\b|package\s+[\w.]+\s*[;{]|namespace\s+[\w.]+\s*[{;]|public\s+(?:static\s+|final\s+|abstract\s+)?[\w<>\[\],. ]+\s+\w+\s*\(|private\s+(?:static\s+|final\s+)?[\w<>\[\],. ]+\s+\w+\s*\(|protected\s+[\w<>\[\],. ]+\s+\w+\s*\(|const\s+[\w$]+\s*=|let\s+[\w$]+\s*=|var\s+[\w$]+\s*=|export\s+(?:default|const|let|var|function|class|\{)|if\s*\(|for\s*\(|while\s*\(|switch\s*\(|try\s*[:{]|catch\s*\(|except\s+\w+\s*:|async\s+function\b|await\s+[\w([]|module\.exports|impl\s+[\w<]|fn\s+\w+\s*\(|trait\s+\w+|struct\s+\w+|enum\s+\w+\s*[{;]|interface\s+\w+\s*[{;]|template\s*<|<\?xml\b|<!doctype\s|<html\b|<svg\b|<div\b|<body\b|\w+\s*=>)/
// Punctuation shapes: arrow bodies and statement tails.
var codeShapePattern = /=>/;
var codeTailPattern = /[;{}]\s*$|;\s*\n|\)\s*\{|\}\s*[,;]/
var sqlPattern = /^\s*(?:SELECT|INSERT\s+INTO|UPDATE|DELETE\s+FROM|CREATE\s+(?:TABLE|INDEX|VIEW)|ALTER\s+TABLE|DROP\s+(?:TABLE|INDEX)|WITH)\b[\s\S]*\b(?:FROM|SET|INTO|VALUES|WHERE|TABLE|JOIN|ON)\b/i
// Command words that never open an ordinary sentence, so they classify a
// bare "git status" on their own; the everyday ones only count behind a
// path, which keeps "find the file" prose and "/usr/bin/git status" code.
var strongCommands = "sudo|doas|git|npm|npx|pnpm|yarn|bun|pip|pip3|cargo|rustc|go"
                   + "|cmake|ninja|docker|podman|systemctl|journalctl|curl|wget|ssh|scp|rsync"
                   + "|apt|apt-get|pacman|paru|dnf|zypper|flatpak|quickshell|qs|python3?|node"
                   + "|deno|bash|zsh|fish|jq|ffmpeg|gh"
var everydayCommands = "make|find|cat|echo|ls|rm|mv|cp|cd|chmod|chown|grep|rg|egrep|fgrep"
                     + "|man|which|sed|awk|sh|tar|zip|unzip|diff|kill|ps|top|df|du"
var commandPattern = new RegExp("^\\s*(?:" + strongCommands + ")\\s+\\S")
var pathCommandPattern = new RegExp("^(?:~|\\.{1,2})?\\/[\\w.\\-\\/]*\\/(?:"
                                    + strongCommands + "|" + everydayCommands + ")\\s+\\S")
var pathPattern = /^(?:~|\.{1,2})?\/[\w.\-\/]+$/
var bracedPattern = /^\s*[[{][\s\S]*[\]}]\s*$/
var bracedFieldPattern = /["']?[\w-]+["']?\s*:/

function looksLikeCode(text) {
    if (!text.length)
        return false
    if (sqlPattern.test(text) || commandPattern.test(text)
            || pathCommandPattern.test(text) || pathPattern.test(text))
        return true
    if (bracedPattern.test(text) && bracedFieldPattern.test(text))
        return true
    if (codeShapePattern.test(text) || codeTailPattern.test(text))
        return true
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++)
        if (codeLinePattern.test(lines[i]))
            return true
    return false
}

// Category id of one clipboard entry. Accepts both the raw backend row
// (preview / isImage / mime) and the already-mapped result item, so the
// classifier stays independent of where it is called.
function clipCategoryOf(raw) {
    if (!raw)
        return "text"
    if (raw.isImage === true)
        return "image"
    var mime = String(raw.mime == null ? "" : raw.mime).toLowerCase()
    if (mime.indexOf("image/") === 0)
        return "image"
    var preview = String(raw.preview == null
                        ? (raw.previewText == null ? "" : raw.previewText)
                        : raw.preview)
    if (preview.indexOf("[[binary data") === 0)
        return "image"
    var text = preview.trim()
    if (!text.length)
        return "text"
    if (linkPattern.test(text))
        return "link"
    if (colorPattern.test(text) || functionalColorPattern.test(text))
        return "color"
    if (numberPattern.test(text))
        return "number"
    if (looksLikeCode(text))
        return "code"
    return "text"
}

// ---- Chip model ----

var shortcutsTaxonomy = []

// Human label for an id the taxonomy does not describe: shortcut binds carry
// lower-case slugs ("workspaces", "shell"), which read as titles once
// capitalized.
function prettyLabel(id) {
    var text = String(id == null ? "" : id)
    if (!text.length)
        return ""
    return text.charAt(0).toUpperCase() + text.slice(1)
}

function taxonomyFor(mode) {
    var name = String(mode == null ? "" : mode)
    if (name === "apps")
        return appBuckets
    if (name === "clipboard")
        return clipboardTaxonomy
    if (name === "shortcuts")
        return shortcutsTaxonomy
    return []
}

function allLabel(mode) {
    return "All"
}

// Builds the chip bar model from a LauncherLogic.categorySummary() result:
// the unfiltered "All" chip first, then every taxonomy entry in order
// (carrying a 0 count so the bar never reflows while typing), then any id
// outside the taxonomy - a shortcut bind category, for instance.
function chipsFor(mode, summary) {
    var total = summary ? Number(summary.total) : 0
    if (!isFinite(total) || total < 0)
        total = 0
    var chips = [{ id: allId, label: allLabel(mode), count: Math.round(total) }]
    var counts = summary && summary.categories ? summary.categories : []
    var byId = ({})
    for (var i = 0; i < counts.length; i++) {
        var entry = counts[i]
        if (!entry)
            continue
        var id = String(entry.id == null ? "" : entry.id)
        if (!id.length)
            continue
        var count = Number(entry.count)
        byId[countKey(id)] = isFinite(count) && count > 0 ? Math.round(count) : 0
    }
    var taxonomy = taxonomyFor(mode)
    var seen = ({})
    for (var t = 0; t < taxonomy.length; t++) {
        var def = taxonomy[t]
        seen[countKey(def.id)] = true
        var key = countKey(def.id)
        chips.push({
            id: def.id,
            label: def.label,
            count: hasKey(byId, key) ? byId[key] : 0
        })
    }
    var extras = []
    for (var raw in byId) {
        if (!hasKey(byId, raw))
            continue
        if (seen[raw] === true)
            continue
        extras.push(raw)
    }
    extras.sort()
    for (var e = 0; e < extras.length; e++) {
        var extraKey = extras[e]
        var extraId = extraKey.slice(1)
        chips.push({ id: extraId, label: prettyLabel(extraId), count: byId[extraKey] })
    }
    return chips
}