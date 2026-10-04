.pragma library

// Pure parsing/model helpers behind the volume panel's device list and
// application mixer. Split out of VolumeService so the parts that can rot -
// the pactl payload shape and the row assembly - are testable without a
// PipeWire graph (see tests/qml/tst_volume_mixer.qml).
//
// The whole routing feature rests on ONE fact discovered by probing a live
// PipeWire 1.6.9 session: pulse and pipewire keep different id spaces, so a
// pulse sink-input index is NOT a node id (`Sink Input #1351` was node 112).
// But `pactl list sink-inputs` carries the pipewire id inside its property
// block as `object.id`. That is the join key. Falling back to matching on
// application/media names would be a guess, and a guess here silently shows the
// wrong device on the wrong row - the exact "wrong, not stale" failure the
// rest of the service layer is written to avoid.

// Sections the panel reads back-to-front from one pactl invocation.
var ROUTE_SECTION_MARKER = "--afloat--"

// A playback stream is a pipewire sink input. The class string is the precise
// discriminator; `isSink` alone is only a fallback for a node whose properties
// have not landed yet, because `properties` is invalid until the node is bound.
// (Measured on a live session: playback `isStream && isSink`, capture
// `isStream && !isSink`, hardware output `!isStream && isSink`.)
function isPlaybackStream(node) {
    if (!node || node.isStream !== true || node.audio == null)
        return false
    var props = node.properties || {}
    var mediaClass = props["media.class"]
    if (mediaClass !== undefined && mediaClass !== null && String(mediaClass) !== "")
        return String(mediaClass) === "Stream/Output/Audio"
    return node.isSink === true
}

// The shell's own audio node is not a "playing application"; a mixer that lists
// Afloat itself is worse than one that lists nothing.
function isShellStream(node) {
    if (!node)
        return false
    var props = node.properties || {}
    var name = node.name == null ? "" : String(node.name)
    var mediaName = props["media.name"] == null ? "" : String(props["media.name"])
    var appName = props["application.name"] == null ? "" : String(props["application.name"])
    return name === "quickshell" || mediaName === "quickshell" || appName === "quickshell"
}

function text(value, fallback) {
    var raw = value == null ? "" : String(value).trim()
    return raw === "" ? (fallback === undefined ? "" : fallback) : raw
}

// Application identity first, because a stream's node name is frequently the
// bare binary ("Firefox") while several nodes can share it.
function streamAppName(node) {
    if (!node)
        return "Application"
    var props = node.properties || {}
    return text(props["application.name"], text(node.name, "Application"))
}

// Second line of the mixer row. Empty when the app is not playing media, which
// is a real state (a browser holding an idle output stream), not a failure.
function streamMediaName(node) {
    if (!node)
        return ""
    var props = node.properties || {}
    var media = text(props["media.name"])
    if (media !== "" && media !== "(null)")
        return media
    return text(props["media.title"])
}

function streamIconName(node) {
    if (!node)
        return ""
    var props = node.properties || {}
    return text(props["application.icon-name"])
}

// Split the combined pactl stdout into its two JSON documents. The marker is
// required rather than splitting on a newline, because both payloads are
// single-line JSON.
function splitSections(stdout) {
    var text_ = stdout == null ? "" : String(stdout)
    var at = text_.indexOf(ROUTE_SECTION_MARKER)
    if (at === -1)
        return null
    return {
        sinkInputs: text_.slice(0, at),
        sinks: text_.slice(at + ROUTE_SECTION_MARKER.length)
    }
}

function parseJsonArray(raw) {
    var trimmed = raw == null ? "" : String(raw).trim()
    if (trimmed === "")
        return null
    var value = null
    try {
        value = JSON.parse(trimmed)
    } catch (e) {
        return null
    }
    return Array.isArray(value) ? value : null
}

// pulse sink index -> pipewire sink name. Needed because the sink a
// sink-input reports is an index into pulse's own numbering, which again does
// not match the node ids the device list is built from.
function parseSinkNameIndex(raw) {
    var entries = parseJsonArray(raw)
    var map = {}
    if (!entries)
        return null
    for (var i = 0; i < entries.length; i += 1) {
        var entry = entries[i]
        if (!entry)
            continue
        var index = Number(entry.index)
        var name = text(entry.name)
        if (!isFinite(index) || name === "")
            continue
        map[String(index)] = name
    }
    return map
}

// pipewire node id -> routing facts, keyed for O(1) lookup from a mixer row.
function parseStreamRoutes(sinkInputsRaw, sinksRaw) {
    var entries = parseJsonArray(sinkInputsRaw)
    var sinkNames = parseSinkNameIndex(sinksRaw)
    if (!entries || !sinkNames)
        return null
    var routes = {}
    for (var i = 0; i < entries.length; i += 1) {
        var entry = entries[i]
        if (!entry)
            continue
        var props = entry.properties || {}
        var nodeId = parseInt(text(props["object.id"]), 10)
        var pulseIndex = parseInt(text(entry.index), 10)
        if (isNaN(nodeId) || isNaN(pulseIndex))
            continue
        var sinkIndex = Number(entry.sink)
        routes[String(nodeId)] = {
            pulseIndex: pulseIndex,
            sinkIndex: isFinite(sinkIndex) ? sinkIndex : -1,
            sinkName: isFinite(sinkIndex) ? (sinkNames[String(sinkIndex)] || "") : ""
        }
    }
    return routes
}

function routeFor(routes, nodeId) {
    if (!routes || nodeId === undefined || nodeId === null)
        return null
    var entry = routes[String(nodeId)]
    return entry || null
}

// Volume as a 0..1 fraction of the slider's range. PipeWire happily runs a
// node past 1.0 (a mic source was sitting at 1.5), so the raw value is clamped
// rather than trusted, and a non-numeric read is reported as 0 rather than NaN
// so a dead node cannot poison a binding.
function streamLevel(node) {
    if (!node || !node.audio)
        return 0
    var raw = Number(node.audio.volume)
    if (!isFinite(raw))
        return 0
    return Math.max(0, Math.min(1, raw))
}

function streamMuted(node) {
    if (!node || !node.audio)
        return true
    return node.audio.muted === true
}

// Device label for the routing chip. Prefers the description the same
// deviceLabel() uses for the device list, so a name shown in the mixer matches
// the name shown above it.
function sinkLabel(sinkName, devices) {
    var wanted = text(sinkName)
    if (wanted === "")
        return ""
    var list = devices || []
    for (var i = 0; i < list.length; i += 1) {
        var device = list[i]
        if (device && text(device.name) === wanted)
            return text(device.description, wanted)
    }
    return wanted
}