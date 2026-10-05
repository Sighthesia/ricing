.pragma library

// Production launcher data-source adapters: builds the refresh/execute seam
// consumed by LauncherSession from the standalone backend singletons
// (desktop entries + launch counts, cliphist history, niri shortcut binds).
// Pure JavaScript so tests instantiate this exact factory with fixture
// backends; every unavailable source resolves to an explicit { error }
// outcome instead of neutral results.

function normalizeText(value) {
    return value == null ? "" : String(value).replace(/\s+/g, " ").trim()
}

function toCount(value) {
    var number = Number(value)
    return isFinite(number) ? number : 0
}

function containsNormalized(value, needle) {
    return value != null && String(value).toLowerCase().indexOf(needle) >= 0
}

function isSignal(target, name) {
    return !!target && !!target[name] && typeof target[name].connect === "function"
}

// Formats a first-seen timestamp as "MM-dd HH:mm:ss" for row metadata.
function timeLabel(milliseconds) {
    var stamp = new Date(toCount(milliseconds))
    if (isNaN(stamp.getTime()))
        return ""
    return pad2(stamp.getMonth() + 1) + "-" + pad2(stamp.getDate())
            + " " + pad2(stamp.getHours()) + ":"
            + pad2(stamp.getMinutes()) + ":" + pad2(stamp.getSeconds())
}

function pad2(value) {
    var text = String(Math.round(toCount(value)))
    return text.length < 2 ? "0" + text : text
}

// ---- Progressive delivery ----
// A refresh may hand its result set over in several batches instead of one
// array: `done(items, complete)` is called with the first batch synchronously
// and with each following batch from `schedule`, so the surface paints the
// head of the list immediately and the tail streams in behind a spinner
// rather than blocking on the whole mapping.
//
// Two rules make that safe, and both live here rather than in the session:
//  1. ARRIVAL ORDER IS FINAL ORDER. The source is pre-sorted with the same
//     key LauncherLogic.sortResults would use, so appending a batch never
//     reshuffles what is already on screen.
//  2. `schedule` is injected. Production hands a per-frame stepper so no
//     frame is blown; tests hand a synchronous one, so a fixture refresh
//     still delivers every batch inside the refresh() call.
//
// Streams do not cancel each other. A superseded batch is already dropped by
// the session's refresh token, and a cancel would starve the concurrent
// read-only pulls (the clipboard metadata merge runs one while the visible
// list is still streaming). Every state a stream touches - cursor, needle -
// therefore belongs to its own closure rather than to the adapter.

// Chunk sizes chosen so one batch stays a couple of milliseconds of mapping
// even for the widest sets (clipboard history runs to ~750 rows).
var appChunkSize = 48
var clipboardChunkSize = 64
var shortcutChunkSize = 96
// The first batch is what the user sees on the frame the launcher opens, and
// it also builds that many row delegates. Keeping it small makes the opening
// frame cheap.
var firstChunkSize = 24
// What a commit costs is a pool pass and a stretch of the row list, not the
// batch's own mapping, so the number of batches is what the eye feels: a
// dozen tiny ones read as the list twitching as it fills. Each batch after the
// first therefore doubles, up to this ceiling, and the tail converges in a
// handful of commits instead of a dozen.
var maxChunkFactor = 4

// Streams a mapped result set to `done` in chunks. `make` maps one source
// entry to a result (or null to skip it). `matches` filters by the refresh
// needle. Returns once the last batch has been handed over.
function createChunkStream(options) {
    var source = options.source || []
    var make = options.make
    var matches = typeof options.matches === "function" ? options.matches : null
    var schedule = typeof options.schedule === "function" ? options.schedule : null
    var chunkSize = Math.max(1, toCount(options.chunkSize) || 32)
    var firstChunkSize = Math.max(1, toCount(options.firstChunkSize) || chunkSize)
    var maxChunkSize = Math.max(chunkSize, chunkSize * maxChunkFactor)
    var done = options.done
    var index = 0
    var limit = firstChunkSize

    // Returns true once the source is exhausted.
    function step() {
        if (typeof done !== "function")
            return true
        var batch = []
        var scanned = 0
        while (index < source.length && scanned < limit) {
            var raw = source[index]
            index++
            scanned++
            if (!raw)
                continue
            if (matches && !matches(raw))
                continue
            var item = make(raw)
            if (item)
                batch.push(item)
        }
        var complete = index >= source.length
        // Every batch after the first is up to twice the last, so the tail of a
        // long set arrives in a few commits rather than a dozen.
        limit = Math.min(maxChunkSize, Math.max(chunkSize, limit * 2))
        // The final batch always reports, even when empty: an exhausted
        // source with no matches is the legitimate "nothing to show" answer
        // and the session must not wait for a batch that never comes.
        if (batch.length > 0 || complete)
            done(batch, complete)
        return complete
    }

    var finished = step()
    if (!finished && schedule) {
        // Later turns come from the scheduler; this call returns with only the
        // first batch delivered, which is the whole point.
        schedule(function next() {
            if (!step())
                schedule(next)
        })
        return
    }
    // No scheduler means no later turn to come back on - the caller asked for
    // a plain refresh and would otherwise only ever see the first batch.
    while (!finished)
        finished = step()
}

// Sorts a copy of the source with the exact key sortResults uses, so the
// streamed batches arrive in final order. `weightOf`, `usedAtOf` and
// `nameOf` read the raw source entry, which is what keeps the sort free of
// the mapping work this pipeline exists to spread out.
//
// Deriving those keys inside the comparator made this the single most
// expensive step of a clipboard open - about 8ms of a 10ms open, for a source
// cliphist already hands back in the required order. So the source is probed
// first (one key pass, no allocation) and only decorated when there is
// actually something to reorder.
function sortSourceForStreaming(source, weightOf, usedAtOf, nameOf) {
    if (isSourceOrdered(source, weightOf, usedAtOf, nameOf))
        return source
    var decorated = []
    for (var index = 0; index < source.length; index++) {
        var raw = source[index]
        decorated.push({
            raw: raw,
            key: {
                weight: toCount(weightOf(raw)),
                usedAt: toCount(usedAtOf(raw)),
                name: String(nameOf(raw)),
                id: identifier(raw)
            }
        })
    }
    decorated.sort(function (left, right) {
        return compareStreamKeys(left.key, right.key)
    })
    var sorted = []
    for (var out = 0; out < decorated.length; out++)
        sorted.push(decorated[out].raw)
    return sorted
}

// One pass, no allocation: compares neighbours through the accessors directly,
// which is what makes the common "already ranked" source free.
function isSourceOrdered(source, weightOf, usedAtOf, nameOf) {
    if (source.length < 2)
        return true
    var previous = {
        weight: toCount(weightOf(source[0])),
        usedAt: toCount(usedAtOf(source[0])),
        name: String(nameOf(source[0])),
        id: identifier(source[0])
    }
    for (var index = 1; index < source.length; index++) {
        var raw = source[index]
        var current = {
            weight: toCount(weightOf(raw)),
            usedAt: toCount(usedAtOf(raw)),
            name: String(nameOf(raw)),
            id: identifier(raw)
        }
        if (compareStreamKeys(previous, current) > 0)
            return false
        previous = current
    }
    return true
}

// Descending weight, then descending recency, then name and id - the exact
// order LauncherLogic.sortResults establishes, and the same order whether the
// source needed sorting or not.
function compareStreamKeys(left, right) {
    if (left.weight !== right.weight)
        return right.weight - left.weight
    if (left.usedAt !== right.usedAt)
        return right.usedAt - left.usedAt
    var byName = left.name.localeCompare(right.name)
    if (byName !== 0)
        return byName
    return left.id.localeCompare(right.id)
}

function identifier(raw) {
    return raw == null || raw.id == null ? "" : String(raw.id)
}

// ---- Applications ----

function directIconPath(icon) {
    var text = icon == null ? "" : String(icon)
    if (text.indexOf("/") === 0 || text.indexOf("file:") === 0)
        return text
    return ""
}

function appMatches(entry, needle) {
    if (!needle)
        return true
    return containsNormalized(entry.name, needle)
        || containsNormalized(entry.comment, needle)
        || containsNormalized(entry.id, needle)
}

function appItem(entry, launchCounts, iconResolver, categoryResolver) {
    var appId = String(entry.id == null ? "" : entry.id)
    var weight = launchCounts && typeof launchCounts.getLaunchCount === "function"
                 ? toCount(launchCounts.getLaunchCount(appId))
                 : 0
    // Recency breaks frequency ties so a just-launched app surfaces at the
    // front of its frequency band instead of staying alphabetical.
    var lastUsedAt = launchCounts && typeof launchCounts.getLastLaunchAt === "function"
                     ? toCount(launchCounts.getLastLaunchAt(appId))
                     : 0
    var rawIcon = entry.icon == null ? "" : String(entry.icon)
    // Category id from the entry's freedesktop Categories, so the chip bar
    // can narrow the pool without a second scan. The id rides searchText as
    // well: typing "games" then finds every game, matching what the chips
    // advertise.
    var category = categoryResolver ? String(categoryResolver(entry)) : "other"
    return {
        id: appId,
        // A broken .desktop may lack Name; fall back to the id so the app
        // stays listed (and launchable) instead of rendering a blank card.
        displayName: normalizeText(entry.name) || appId,
        description: entry.comment == null ? "" : String(entry.comment),
        searchText: normalizeText(entry.name + " " + entry.comment + " " + entry.id
                                  + " " + category).toLowerCase(),
        icon: iconResolver ? String(iconResolver(rawIcon)) : directIconPath(rawIcon),
        category: category,
        favoriteWeight: weight,
        lastUsedAt: lastUsedAt
    }
}

// ---- Built-in shell commands ----

// Shell-managed actions surfaced beside applications so they are reachable
// from plain queries without memorizing IPC targets. Execution reuses the
// managed-bind seam: actionArgv routes actionId "shell.<target>.<fn>" through
// the afloat IPC helper.
function builtinCommands() {
    return [{
        id: "cmd-lock",
        label: "锁屏",
        description: "Lock the session",
        keywords: "lock lockscreen 锁屏 锁定 锁定屏幕",
        icon: "lock",
        category: "system",
        actionId: "shell.lock.lock"
    }]
}

function commandMatches(command, needle) {
    if (!needle)
        return true
    return containsNormalized(command.label, needle)
        || containsNormalized(command.description, needle)
        || containsNormalized(command.keywords, needle)
}

function commandItem(command, index, iconResolver) {
    var label = command.label == null ? "" : String(command.label)
    var description = command.description == null ? "" : String(command.description)
    var rawIcon = command.icon == null ? "" : String(command.icon)
    return {
        id: command.id == null ? "builtin-" + index : String(command.id),
        kind: "command",
        displayName: label,
        description: description,
        searchText: normalizeText(label + " " + description + " "
                                  + (command.keywords == null ? "" : String(command.keywords))).toLowerCase(),
        // Through the resolver like every app icon: a bare theme NAME is not a
        // source. Handed to Image.source raw, "lock" resolved as a relative
        // file path against the row's own directory, errored for good, and the
        // card rendered with its text and an empty icon slot.
        icon: iconResolver ? String(iconResolver(rawIcon))
                           : (rawIcon.indexOf("/") === 0 || rawIcon.indexOf("file:") === 0
                              || rawIcon.indexOf(":") > 0 ? rawIcon : ""),
        actionId: command.actionId == null ? "" : String(command.actionId),
        managedByShell: true,
        // Built-in commands declare their own chip bucket so they ride the
        // same category lens as desktop entries.
        category: command.category == null ? "other" : String(command.category),
        favoriteWeight: toCount(command.favoriteWeight),
        lastUsedAt: 0
    }
}

// Desktop-entry applications: favorites from launch counts drive ordering,
// execution launches through the entry itself and records recent use.
// Optional built-in shell commands ride the same result set and route their
// execution through the shared IPC helper seam.
function createAppsAdapter(config) {
    config = config || {}
    var source = config.appsSource || null
    var launchCounts = config.launchCounts || null
    var iconResolver = typeof config.iconResolver === "function" ? config.iconResolver : null
    var categoryResolver = typeof config.categoryResolver === "function" ? config.categoryResolver : null
    var commands = Array.isArray(config.commands) ? config.commands : []
    var actionRunner = typeof config.actionRunner === "function" ? config.actionRunner : null
    var ipcHelperPath = config.ipcHelperPath == null ? "" : String(config.ipcHelperPath)
    var schedule = typeof config.schedule === "function" ? config.schedule : null

    // Icon resolution hits the icon theme (a synchronous filesystem-backed
    // lookup per name); cache by raw icon name so repeated pool pulls -
    // rescans, revalidations - never re-pay it. Misses resolve to "" but are
    // deliberately NOT cached: an early lookup during the desktop-entry scan
    // or before the icon theme settles would otherwise poison the entry and
    // leave the icon blank until restart, even though a later lookup
    // succeeds. Only hits are cached.
    var iconCache = {}
    function cachedIcon(rawIcon) {
        var key = rawIcon == null ? "" : String(rawIcon)
        if (Object.prototype.hasOwnProperty.call(iconCache, key))
            return iconCache[key]
        // Absolute and file URLs already identify the image. Sending them to
        // QIcon::fromTheme treats a valid file path as a theme name and turns
        // it into an empty result.
        var resolved = directIconPath(key)
        if (!resolved && iconResolver)
            resolved = String(iconResolver(key))
        if (resolved)
            iconCache[key] = resolved
        return resolved
    }

    // DesktopEntries.applications.values is a QML list object rather than a
    // JavaScript array; accept anything indexable with a numeric length.
    function entryValues() {
        if (!source || !source.values)
            return null
        var values = source.values
        return typeof values.length === "number" ? values : null
    }

    function findEntry(id) {
        var values = entryValues()
        if (!values)
            return null
        var wanted = String(id == null ? "" : id)
        for (var index = 0; index < values.length; index++) {
            var candidate = values[index]
            if (candidate && String(candidate.id) === wanted)
                return candidate
        }
        return null
    }

    // Everything the stream maps, in the order sortResults would rank it:
    // the hidden and built-in command rows ride the same batch run so they
    // land with the applications instead of trailing the whole list.
    function streamSource() {
        var values = entryValues() || []
        var entries = []
        for (var index = 0; index < values.length; index++) {
            var entry = values[index]
            if (entry && !entry.noDisplay)
                entries.push(entry)
        }
        var apps = sortSourceForStreaming(entries,
            function(entry) {
                var appId = String(entry.id == null ? "" : entry.id)
                return launchCounts && typeof launchCounts.getLaunchCount === "function"
                       ? launchCounts.getLaunchCount(appId) : 0
            },
            function(entry) {
                var appId = String(entry.id == null ? "" : entry.id)
                return launchCounts && typeof launchCounts.getLastLaunchAt === "function"
                       ? launchCounts.getLastLaunchAt(appId) : 0
            },
            // Mirrors appItem's displayName, including the id fallback for a
            // broken .desktop, so the pre-sort cannot disagree with it.
            function(entry) { return normalizeText(entry.name) || String(entry.id == null ? "" : entry.id) })
        var ordered = apps.slice()
        for (var commandIndex = 0; commandIndex < commands.length; commandIndex++) {
            var command = commands[commandIndex]
            if (command)
                ordered.push({ isCommand: true, index: commandIndex, command: command })
        }
        return ordered
    }

    function mapStreamed(raw) {
        if (raw.isCommand)
            return commandItem(raw.command, raw.index, cachedIcon)
        return appItem(raw, launchCounts, cachedIcon, categoryResolver)
    }

    return {
        refresh: function(queryText, modeName, done) {
            if (typeof done !== "function")
                return
            var values = entryValues()
            if (!values) {
                done({ error: "application source unavailable" })
                return
            }
            // The needle lives in this refresh's closure: a concurrent refresh
            // must not retarget a stream that is still delivering.
            var needle = normalizeText(queryText).toLowerCase()
            createChunkStream({
                source: streamSource(),
                make: mapStreamed,
                matches: function(raw) {
                    if (!needle)
                        return true
                    return raw.isCommand ? commandMatches(raw.command, needle)
                                         : appMatches(raw, needle)
                },
                schedule: schedule,
                firstChunkSize: firstChunkSize,
                chunkSize: appChunkSize,
                done: done
            })
        },

        execute: function(item, done) {
            if (typeof done !== "function")
                return
            // Built-in commands execute through the managed-bind seam.
            if (item && item.kind === "command") {
                if (!actionRunner) {
                    done({ ok: false, error: "command actions unavailable" })
                    return
                }
                var argv = actionArgv(item, ipcHelperPath)
                if (!argv.length) {
                    done({ ok: false, error: "command has no runnable action" })
                    return
                }
                actionRunner(argv, done)
                return
            }
            if (!entryValues()) {
                done({ ok: false, error: "application source unavailable" })
                return
            }
            if (!item || !(item.id != null && String(item.id).length)) {
                done({ ok: false, error: "no application selected" })
                return
            }
            var entry = findEntry(item.id)
            if (!entry) {
                done({ ok: false, error: "application not found: " + String(item.displayName || item.id) })
                return
            }
            if (typeof entry.execute !== "function") {
                done({ ok: false, error: "application cannot be launched: " + String(entry.name || entry.id) })
                return
            }
            // entry.execute() reports failure through a false return or a
            // thrown exception; either way done() must fire so the session
            // never strands between "row hidden for fling" and "closed".
            var launched = true
            try {
                launched = entry.execute()
            } catch (err) {
                done({ ok: false, error: "application launch failed: " + String(entry.name || entry.id) })
                return
            }
            if (launched === false) {
                done({ ok: false, error: "application failed to launch: " + String(entry.name || entry.id) })
                return
            }
            if (launchCounts && typeof launchCounts.recordLaunch === "function")
                launchCounts.recordLaunch(String(entry.id))
            done({ ok: true })
        }
    }
}

// ---- Clipboard ----

function clipboardByteCount(text) {
    var match = /^\s*([\d.]+)\s*(B|KB|MB|GB|TB|KIB|MIB|GIB|TIB)?\s*$/i.exec(text == null ? "" : String(text))
    if (!match)
        return NaN
    var value = Number(match[1])
    var unit = (match[2] || "B").toUpperCase()
    if (unit === "B")
        return Math.round(value)
    if (unit === "KB")
        return Math.round(value * 1000)
    if (unit === "MB")
        return Math.round(value * 1000000)
    if (unit === "GB")
        return Math.round(value * 1000000000)
    if (unit === "TB")
        return Math.round(value * 1000000000000)
    if (unit === "KIB")
        return Math.round(value * 1024)
    if (unit === "MIB")
        return Math.round(value * 1048576)
    if (unit === "GIB")
        return Math.round(value * 1073741824)
    if (unit === "TIB")
        return Math.round(value * 1099511627776)
    return NaN
}

function formatClipboardByteSize(bytes) {
    var count = Number(bytes)
    if (!isFinite(count) || count < 0)
        return ""
    var units = ["B", "KB", "MB", "GB", "TB"]
    var value = count
    var unitIndex = 0
    while (value >= 1000 && unitIndex < units.length - 1) {
        value = value / 1000
        unitIndex++
    }
    if (unitIndex === 0)
        return Math.round(value) + " B"
    return (Math.round(value * 10) / 10) + " " + units[unitIndex]
}

function isValidClipboardMetadataCache(item, cached) {
    if (!item || !cached || typeof cached !== "object")
        return false
    if (!!cached.isImage !== !!item.isImage)
        return false
    if (String(cached.preview == null ? "" : cached.preview)
            !== String(item.preview == null ? "" : item.preview))
        return false
    if (cached.isImage) {
        return typeof cached.format === "string" && cached.format.length > 0
            && Number(cached.width) > 0 && Number(cached.height) > 0
            && Number(cached.bytes) >= 0
    }
    return Number(cached.textCharCount) >= 0
}

function applyClipboardMetadataCache(items, metadataMap) {
    if (!Array.isArray(items) || !metadataMap || typeof metadataMap !== "object")
        return 0
    var applied = 0
    for (var index = 0; index < items.length; index++) {
        var item = items[index]
        if (!item) {
            continue
        }
        var cached = metadataMap[String(item.id)]
        if (!isValidClipboardMetadataCache(item, cached)) {
            item.metadataReady = false
            continue
        }
        if (cached.isImage) {
            item.imageFormat = cached.format
            item.imageWidth = Number(cached.width)
            item.imageHeight = Number(cached.height)
            item.imageBytes = Number(cached.bytes)
        } else {
            item.textCharCount = Number(cached.textCharCount)
        }
        item.metadataReady = true
        applied++
    }
    return applied
}

// Copy seeds remember the timestamps of entries the shell itself just
// copied back: copy/paste replays content through wl-copy, so cliphist
// deletes and recreates the row with a fresh id. When the recreated row
// surfaces with an unknown id it inherits the original timestamp instead
// of Date.now(), so the entry never visibly jumps to the top and back once
// the async content-signature recovery confirms the same timestamp.
var clipboardCopySeedMaxAgeMs = 60000
var clipboardCopySeedLimit = 16

function rememberClipboardCopySeed(seeds, preview, isImage, firstSeenMs, nowMs) {
    var list = Array.isArray(seeds) ? seeds.slice() : []
    var seen = Number(firstSeenMs)
    if (!isFinite(seen) || seen <= 0)
        seen = Number(nowMs) || 0
    var now = Number(nowMs) || 0
    list.push({
        preview: preview == null ? "" : String(preview),
        isImage: !!isImage,
        firstSeenMs: seen,
        at: now
    })
    var fresh = []
    var cutoff = now - clipboardCopySeedMaxAgeMs
    for (var index = 0; index < list.length; index++) {
        var seed = list[index]
        if (seed && Number(seed.at) >= cutoff)
            fresh.push(seed)
    }
    while (fresh.length > clipboardCopySeedLimit)
        fresh.shift()
    return fresh
}

function matchClipboardCopySeed(seeds, preview, isImage, nowMs) {
    if (!Array.isArray(seeds) || !seeds.length)
        return 0
    var wantedPreview = preview == null ? "" : String(preview)
    var wantedImage = !!isImage
    var cutoff = (Number(nowMs) || 0) - clipboardCopySeedMaxAgeMs
    for (var index = seeds.length - 1; index >= 0; index--) {
        var seed = seeds[index]
        if (!seed || Number(seed.at) < cutoff)
            continue
        if (!!seed.isImage !== wantedImage)
            continue
        if (String(seed.preview == null ? "" : seed.preview) !== wantedPreview)
            continue
        var seen = Number(seed.firstSeenMs)
        return isFinite(seen) && seen > 0 ? seen : 0
    }
    return 0
}

// Preview decode queue: a single cliphist decode runs at a time and every
// completion keeps its own id. New requests wait instead of overwriting the
// running id (which misattributed the in-flight content to the newest
// request, so preview text stopped following the selection). Consumed
// newest-first so rapid navigation previews the current selection within
// one decode; every queued decode still completes and fills its cache.
function queuePreviewDecode(queue, id, isImage) {
    var list = Array.isArray(queue) ? queue : []
    var key = id == null ? "" : String(id)
    if (!key)
        return list
    for (var index = 0; index < list.length; index++) {
        if (list[index] && String(list[index].id) === key)
            return list
    }
    list.push({ id: key, isImage: !!isImage })
    return list
}

function takeNewestPreviewDecode(queue) {
    if (!Array.isArray(queue) || !queue.length)
        return null
    return queue.pop()
}

// First-seen persistence: id->timestamp rows survive restarts so a cold boot
// paints correct dates and order immediately instead of stamping everything
// with boot time until signature recovery corrects it row by row. The stored
// shape is { signatures: {...}, ids: {...} }; a legacy bare signature map
// still loads as signatures with empty ids.
function splitFirstSeenCache(stored) {
    var empty = { signatures: ({}), ids: ({}) }
    if (!stored || typeof stored !== "object" || Array.isArray(stored))
        return empty
    if (stored.signatures && typeof stored.signatures === "object"
            && !Array.isArray(stored.signatures)
            && stored.ids && typeof stored.ids === "object"
            && !Array.isArray(stored.ids))
        return { signatures: stored.signatures, ids: stored.ids }
    return { signatures: stored, ids: ({}) }
}

function packFirstSeenCache(signatures, firstSeenById, items) {
    var liveIds = ({})
    if (Array.isArray(items)) {
        for (var index = 0; index < items.length; index++) {
            var item = items[index]
            if (item && item.id != null)
                liveIds[String(item.id)] = true
        }
    }
    var ids = ({})
    if (firstSeenById && typeof firstSeenById === "object") {
        for (var key in firstSeenById) {
            if (!Object.prototype.hasOwnProperty.call(firstSeenById, key))
                continue
            if (!liveIds[key])
                continue
            var seen = Number(firstSeenById[key])
            if (isFinite(seen) && seen > 0)
                ids[key] = seen
        }
    }
    return {
        signatures: signatures && typeof signatures === "object" ? signatures : ({}),
        ids: ids
    }
}

// Splits one "<id>\t<preview>" cliphist list row; null for blank lines.
// Pure so the history row parse stays unit-testable without a Quickshell
// process (a scope slip here used to abort the whole fetch mid-loop).
function splitClipboardListLine(line) {
    var text = line == null ? "" : String(line)
    if (!text)
        return null
    var tab = text.indexOf("\t")
    var id = tab >= 0 ? text.slice(0, tab) : text.split(" ")[0]
    var preview = tab >= 0 ? text.slice(tab + 1) : text.slice(id.length + 1)
    return { id: id, preview: preview }
}

// cliphist marks binary/image entries with the exact "[[ binary data ... ]"
// preview prefix; loose substring matches misclassify text that merely
// mentions <img.
function isClipboardImagePreview(preview) {
    return String(preview == null ? "" : preview).startsWith("[[")
}

function clipboardMimeForPreview(preview, isImage) {
    if (!isImage)
        return "text/plain"
    var lower = String(preview == null ? "" : preview).toLowerCase()
    if (lower.includes("png"))
        return "image/png"
    if (lower.includes("jpg") || lower.includes("jpeg"))
        return "image/jpeg"
    if (lower.includes("webp"))
        return "image/webp"
    if (lower.includes("gif"))
        return "image/gif"
    return "image/*"
}

function parseClipboardImageMeta(preview) {
    if (typeof preview !== "string")
        return null
    var match = /^\[\[\s*binary data\s+([\d.]+\s*(?:KiB|MiB|GiB|B)|[^\s]+)\s+([^\s]+)\s+(\d+)x(\d+)\s*\]\]$/.exec(preview.trim())
    if (!match)
        return null
    return {
        size: match[1],
        format: match[2],
        width: Number(match[3]),
        height: Number(match[4])
    }
}

function clipboardItem(raw, categoryResolver) {
    var preview = raw.preview == null ? "" : String(raw.preview)
    var isImage = !!raw.isImage
    var mime = raw.mime == null ? "text/plain" : String(raw.mime)
    var seenMs = toCount(raw.firstSeenMs)
    var imageMeta = isImage ? parseClipboardImageMeta(preview) : null
    var metadataReady = raw.metadataReady === true
    // Content-derived bucket (image / link / code / color / number / text)
    // so the clipboard list can be narrowed by kind without tagging entries
    // by hand. The id also rides searchText, keeping "code" and "link"
    // searchable next to the entry text itself.
    var category = categoryResolver ? String(categoryResolver(raw))
                                    : (isImage ? "image" : "text")
    var title = isImage
                 ? (metadataReady && Number(raw.imageWidth) > 0 && Number(raw.imageHeight) > 0
                    ? "[Image] " + Number(raw.imageWidth) + "x" + Number(raw.imageHeight)
                    : imageMeta ? "[Image] " + imageMeta.width + "x" + imageMeta.height : "[Image]")
                 : (normalizeText(preview).length ? preview : "(empty)")
    var description = mime
    if (isImage) {
        var exactBytes = Number(raw.imageBytes)
        if (metadataReady && raw.imageFormat && isFinite(exactBytes) && exactBytes >= 0)
            description += " | " + raw.imageFormat + " | " + formatClipboardByteSize(exactBytes)
        else if (imageMeta)
            description += " | " + imageMeta.format + " | " + formatClipboardByteSize(clipboardByteCount(imageMeta.size))
    } else if (metadataReady && Number(raw.textCharCount) >= 0)
        description += " | " + Number(raw.textCharCount) + " characters"
    else
        description += " | " + (preview.length >= 100 ? "counting..." : preview.length + " characters")
    var seen = timeLabel(seenMs)
    if (seen)
        description += " · copied " + seen
    return {
        id: raw.id == null ? "" : String(raw.id),
        displayName: title,
        description: description,
        searchText: normalizeText(title + " " + description + " " + category).toLowerCase(),
        icon: "",
        previewText: preview,
        mime: mime,
        isImage: isImage,
        time: seenMs,
        category: category,
        favoriteWeight: 0,
        lastUsedAt: seenMs
    }
}

// Clipboard rows carry no usage weight, so sortResults ranks them by
// first-seen time alone; the pre-sort therefore only has to order by that
// timestamp to keep arrival order equal to final order. The exact ties that
// sortResults would break by title are two copies inside the same
// millisecond, and the batch they land in is still the same batch.
function clipboardStreamSource(items) {
    var source = []
    for (var index = 0; index < items.length; index++)
        if (items[index])
            source.push(items[index])
    return sortSourceForStreaming(source,
        function() { return 0 },
        function(raw) { return toCount(raw.firstSeenMs) },
        function() { return "" })
}

// Cliphist-backed clipboard history: write-back copies the selected entry;
// the very first fetch may still be in flight, so the initial refresh waits
// once for listCompletion instead of reporting an empty history.
function createClipboardAdapter(config) {
    config = config || {}
    var backend = config.clipboardBackend || null
    var categoryResolver = typeof config.categoryResolver === "function" ? config.categoryResolver : null
    var schedule = typeof config.schedule === "function" ? config.schedule : null
    var waiting = null
    var completionHandler = null
    var availabilityHandler = null

    function settle() {
        if (!completionHandler)
            return
        try { backend.listCompleted.disconnect(completionHandler) } catch (e) {}
        completionHandler = null
        var pending = waiting
        waiting = null
        if (pending)
            stream(pending.needle, pending.done)
    }

    // Streams the history the backend already holds: the first batch paints in
    // this same turn and the rest follows one frame apart.
    function stream(needle, done) {
        createChunkStream({
            source: clipboardStreamSource(Array.isArray(backend.items) ? backend.items : []),
            make: function(raw) { return clipboardItem(raw, categoryResolver) },
            matches: function(raw) {
                return !needle || containsNormalized(raw.preview, needle)
            },
            schedule: schedule,
            firstChunkSize: firstChunkSize,
            chunkSize: clipboardChunkSize,
            done: done
        })
    }

    // During the startup probe the service is not yet marked available.
    // Rather than surfacing an instant error that forces a manual retry,
    // hold the request until availability flips, then re-run the normal
    // fetch path. Definitive unavailability (probe finished, still false)
    // still errors immediately.
    function armAvailabilityWait(queryText, modeName, done) {
        if (availabilityHandler) {
            try { backend.availableChanged.disconnect(availabilityHandler) } catch (e) {}
            availabilityHandler = null
        }
        availabilityHandler = function() {
            try { backend.availableChanged.disconnect(availabilityHandler) } catch (e) {}
            availabilityHandler = null
            if (!backend.available)
                return
            refresh(queryText, modeName, done)
        }
        backend.availableChanged.connect(availabilityHandler)
    }

    function refresh(queryText, modeName, done) {
            if (typeof done !== "function")
                return
            if (!backend) {
                done({ error: "clipboard service unavailable" })
                return
            }
            if (!backend.available) {
                if (isSignal(backend, "availableChanged") && backend.probeFinished === false) {
                    armAvailabilityWait(queryText, modeName, done)
                    return
                }
                done({ error: "clipboard history unavailable" })
                return
            }
            var needle = normalizeText(queryText).toLowerCase()
            var items = Array.isArray(backend.items) ? backend.items : []
            // Wait when history has never loaded OR a fresh fetch is in
            // flight; returning immediately would surface stale content
            // that then requires reopening the panel to update.
            var canWait = (toCount(backend.revision) <= 0 || backend.listing === true)
                          && isSignal(backend, "listCompleted")
                          && typeof backend.list === "function"
            if (items.length > 0 || !canWait) {
                stream(needle, done)
                return
            }
            // list() is a documented no-op until the backend's startup caches
            // land; entering the wait for a completion that was never armed
            // would stick the session on "Searching..." forever. Answer with
            // what we have instead — later polls/completions refill once the
            // backend is ready. Backends without the seam (test doubles) keep
            // the previous waiting behavior.
            if (backend._firstSeenCacheReady === false) {
                stream(needle, done)
                return
            }
            waiting = { needle: needle, done: done }
            if (!completionHandler) {
                completionHandler = settle
                backend.listCompleted.connect(completionHandler)
            }
            backend.list()
    }

    function execute(item, done) {
            if (typeof done !== "function")
                return
            if (!backend) {
                done({ ok: false, error: "clipboard service unavailable" })
                return
            }
            if (!backend.available) {
                done({ ok: false, error: "clipboard history unavailable" })
                return
            }
            if (!item || !(item.id != null && String(item.id).length)) {
                done({ ok: false, error: "no clipboard entry selected" })
                return
            }
            if (typeof backend.copyItem === "function")
                backend.copyItem(String(item.id))
            done({ ok: true })
    }

    var adapter = { refresh: refresh, execute: execute }
    return adapter
}

// ---- Shortcuts ----

function modelRows(model) {
    var count = model ? toCount(model.count) : 0
    var rows = []
    if (!count || typeof model.get !== "function")
        return rows
    for (var index = 0; index < count; index++) {
        var row = model.get(index)
        if (row)
            rows.push(row)
    }
    return rows
}

function shortcutMatches(row, needle) {
    if (!needle)
        return true
    return containsNormalized(row.label, needle)
        || containsNormalized(row.sequence, needle)
        || containsNormalized(row.detail, needle)
        || containsNormalized(row.category, needle)
}

function shortcutItem(row, index) {
    var sequence = row.sequence == null ? "" : String(row.sequence)
    var detail = row.detail == null ? "" : String(row.detail)
    return {
        id: row.entryId == null ? "shortcut-" + index : String(row.entryId),
        displayName: row.label == null ? "" : String(row.label),
        description: detail ? sequence + " · " + detail : sequence,
        searchText: normalizeText(row.label + " " + sequence + " " + detail + " " + row.category).toLowerCase(),
        keySequence: sequence,
        detail: detail,
        actionId: row.actionId == null ? "" : String(row.actionId),
        category: row.category == null ? "" : String(row.category),
        managedByShell: !!row.managedByShell,
        favoriteWeight: 0,
        lastUsedAt: 0
    }
}

// Binds carry no usage weight, so sortResults ranks them alphabetically by
// label; ordering the raw rows that way first lets the batches stream in
// their final order.
function shortcutStreamSource(rows) {
    var source = []
    for (var index = 0; index < rows.length; index++)
        if (rows[index])
            source.push({ row: rows[index], index: index,
                      id: rows[index].entryId == null ? "" : String(rows[index].entryId) })
    return sortSourceForStreaming(source,
        function() { return 0 },
        function() { return 0 },
        function(raw) { return raw.row.label == null ? "" : String(raw.row.label) })
}

// Splits a kdl action body into argv tokens, honoring double-quoted strings
// and backslash escapes so spawn arguments survive intact.
function tokenizeActionBody(body) {
    var text = body == null ? "" : String(body)
    var tokens = []
    var current = ""
    var started = false
    var quoted = false
    for (var index = 0; index < text.length; index++) {
        var character = text[index]
        if (character === "\\" && index + 1 < text.length) {
            current += text[index + 1]
            started = true
            index++
            continue
        }
        if (character === "\"") {
            quoted = !quoted
            started = true
            continue
        }
        if (!quoted && /\s/.test(character)) {
            if (started) {
                tokens.push(current)
                current = ""
                started = false
            }
            continue
        }
        current += character
        started = true
    }
    if (started)
        tokens.push(current)
    return tokens
}

function shellIpcParts(actionId) {
    var match = /^shell\.([a-z0-9_-]+)\.([a-z0-9_-]+)$/i.exec(actionId == null ? "" : String(actionId))
    return match ? [match[1], match[2]] : null
}

// Builds the argv executing one shortcut result: shell-managed binds go
// through the afloat IPC helper, everything else runs as a niri action.
function actionArgv(item, ipcHelperPath) {
    if (!item)
        return []
    if (item.managedByShell) {
        var parts = shellIpcParts(item.actionId)
        if (parts && ipcHelperPath)
            return [String(ipcHelperPath), parts[0], parts[1]]
    }
    var tokens = tokenizeActionBody(item.detail != null ? item.detail : item.actionSummary)
    if (!tokens.length)
        return []
    var head = tokens[0]
    var argv = ["niri", "msg", "action", head]
    if (head === "spawn" || head === "spawn-sh")
        argv.push("--")
    return argv.concat(tokens.slice(1))
}

// Niri shortcut bindings: entries come from the parsed binds model and
// execution routes through niri msg (or the shell IPC helper).
function createShortcutsAdapter(config) {
    config = config || {}
    var backend = config.shortcutsBackend || null
    var actionRunner = typeof config.actionRunner === "function" ? config.actionRunner : null
    var ipcHelperPath = config.ipcHelperPath == null ? "" : String(config.ipcHelperPath)
    var schedule = typeof config.schedule === "function" ? config.schedule : null

    function stream(needle, done) {
        createChunkStream({
            source: shortcutStreamSource(modelRows(backend.shortcutsModel)),
            make: function(raw) { return shortcutItem(raw.row, raw.index) },
            matches: function(raw) { return shortcutMatches(raw.row, needle) },
            schedule: schedule,
            firstChunkSize: firstChunkSize,
            chunkSize: shortcutChunkSize,
            done: done
        })
    }

    function evaluate(needle, done) {
        var rows = modelRows(backend.shortcutsModel)
        if (!rows.length && backend.errorText) {
            done({ error: String(backend.errorText) })
            return
        }
        stream(needle, done)
    }

    return {
        refresh: function(queryText, modeName, done) {
            if (typeof done !== "function")
                return
            if (!backend) {
                done({ error: "shortcut service unavailable" })
                return
            }
            var needle = normalizeText(queryText).toLowerCase()
            if (backend.isLoaded || !isSignal(backend, "shortcutsReloaded")) {
                evaluate(needle, done)
                return
            }
            // Binds file still loading: settle on either the successful
            // reload or a surfaced load error before answering.
            var settled = false
            var handlers = []
            var finish = function() {
                if (settled)
                    return
                settled = true
                for (var index = 0; index < handlers.length; index++) {
                    try { handlers[index][0].disconnect(handlers[index][1]) } catch (e) {}
                }
                evaluate(needle, done)
            }
            handlers.push([backend.shortcutsReloaded, finish])
            if (isSignal(backend, "errorTextChanged"))
                handlers.push([backend.errorTextChanged, finish])
            for (var index = 0; index < handlers.length; index++)
                handlers[index][0].connect(handlers[index][1])
        },

        execute: function(item, done) {
            if (typeof done !== "function")
                return
            if (!backend) {
                done({ ok: false, error: "shortcut service unavailable" })
                return
            }
            if (!actionRunner) {
                done({ ok: false, error: "shortcut actions unavailable" })
                return
            }
            if (!item) {
                done({ ok: false, error: "no shortcut selected" })
                return
            }
            var argv = actionArgv(item, ipcHelperPath)
            if (!argv.length) {
                done({ ok: false, error: "shortcut has no runnable action" })
                return
            }
            actionRunner(argv, done)
        }
    }
}

// Assembles the full mode-keyed adapter set handed to LauncherSession.
function createAdapters(config) {
    config = config || {}
    return {
        apps: createAppsAdapter({
            appsSource: config.appsSource || null,
            launchCounts: config.launchCounts || null,
            iconResolver: config.iconResolver || null,
            categoryResolver: config.appCategoryResolver || null,
            commands: config.commands,
            actionRunner: config.actionRunner,
            ipcHelperPath: config.ipcHelperPath,
            schedule: config.schedule
        }),
        clipboard: createClipboardAdapter({
            clipboardBackend: config.clipboardBackend || null,
            categoryResolver: config.clipCategoryResolver || null,
            schedule: config.schedule
        }),
        shortcuts: createShortcutsAdapter({
            shortcutsBackend: config.shortcutsBackend || null,
            actionRunner: config.actionRunner || null,
            ipcHelperPath: config.ipcHelperPath || "",
            schedule: config.schedule
        })
    }
}
