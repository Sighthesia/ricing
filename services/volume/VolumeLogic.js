.pragma library

// Pure parsing/model helpers behind the volume panel's device list and
// application mixer. Split out of VolumeService so the parts that can rot -
// the pactl payload shape and the row assembly - can be checked without a
// PipeWire graph.
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

// The longest leading run of words shared by at least two labels.
//
// PipeWire descriptions are dominated by a hardware-card prefix ("Ryzen HD Audio
// Controller Stereo Microphone"), which on a three-microphone machine pushed the
// part that actually tells the microphones apart off the end of every row.
//
// "At least two, not all" is the load-bearing part. A list of two Ryzen
// microphones and one Bluetooth headset intersects to nothing at all, so an
// all-rows rule would decline to hoist anything and put the long name back on
// every row. The headset is left whole, which is correct - it never had the
// prefix to lose. Conversely a run only one label carries is not a prefix at
// all: "Ryzen HD Audio Controller" and "TimeEar BTE-9" must not hoist
// "Ryzen HD Audio Controller" just because it is the longest thing in common.
//
// Returns "" when there is nothing worth hoisting: fewer than two labels, a run
// shared by fewer than two of them, a run that is the whole of some row (which
// would leave that row blank), or a one-word majority (see the guard below).
function sharedLabelPrefix(labels) {
    var list = labels || []
    if (list.length < 2)
        return ""
    var firstWords = text(list[0]).split(" ")
    var best = []
    var bestCount = 0
    for (var take = 1; take <= firstWords.length; take += 1) {
        var candidate = firstWords.slice(0, take).join(" ")
        var count = 0
        for (var i = 0; i < list.length; i += 1) {
            var candidateLabel = text(list[i])
            if (candidateLabel === candidate
                    || candidateLabel.indexOf(candidate + " ") === 0)
                count += 1
        }
        // `>=`, so the longest run wins a tie: "Razer - BlackWidow" / "Razer -
        // Naga" hoists the full "Razer -" and the trailing-punctuation strip
        // below turns it back into "Razer".
        if (count >= bestCount) {
            bestCount = count
            best = firstWords.slice(0, take)
        }
    }
    // Shared by fewer than two labels is not a shared prefix.
    if (best.length === 0 || bestCount < 2)
        return ""
    // A run every row carries may be a single word. A run only some rows carry
    // must be at least two: one shared word among otherwise unrelated devices
    // would trim rows into fragments without saying anything true about the
    // group.
    if (bestCount < list.length && best.length < 2)
        return ""
    // Trailing punctuation would read as a dangling dash in the header.
    var joined = best.join(" ").replace(/[\s,;:.\-–—]+$/, "")
    if (joined === "")
        return ""
    for (var j = 0; j < list.length; j++) {
        if (text(list[j]) === joined)
            return ""
    }
    return joined
}

// The row's own label with the hoisted prefix removed, falling back to the full
// label when nothing can be trimmed.
function trimLabelPrefix(label, prefix) {
    var full = text(label)
    if (!prefix)
        return full
    var trimmed = full.slice(prefix.length).replace(/^[\s,;:.\-–—]+/, "")
    return trimmed === "" ? full : trimmed
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