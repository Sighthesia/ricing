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

function appItem(entry, launchCounts, iconResolver) {
    var weight = launchCounts && typeof launchCounts.getLaunchCount === "function"
                 ? toCount(launchCounts.getLaunchCount(String(entry.id == null ? "" : entry.id)))
                 : 0
    var rawIcon = entry.icon == null ? "" : String(entry.icon)
    return {
        id: entry.id == null ? "" : String(entry.id),
        // A broken .desktop may lack Name; fall back to the id so the app
        // stays listed (and launchable) instead of rendering a blank card.
        displayName: normalizeText(entry.name) || String(entry.id == null ? "" : entry.id),
        description: entry.comment == null ? "" : String(entry.comment),
        searchText: normalizeText(entry.name + " " + entry.comment + " " + entry.id).toLowerCase(),
        icon: iconResolver ? String(iconResolver(rawIcon)) : directIconPath(rawIcon),
        favoriteWeight: weight,
        lastUsedAt: 0
    }
}

// ---- Built-in shell commands ----

// Shell-managed actions surfaced beside applications so they are reachable
// from plain queries without memorizing IPC targets. Execution reuses the
// managed-bind seam: actionArgv routes actionId "shell.<target>.<fn>" through
// the afloat IPC helper.
function builtinCommands() {
    return [
        {
            id: "builtin-lock",
            label: "锁定屏幕",
            description: "锁屏 · lock screen",
            keywords: "lock 锁屏 锁定 屏幕 lockscreen",
            icon: "icons/lock.svg",
            actionId: "shell.lock.activate"
        }
    ]
}

function commandMatches(command, needle) {
    if (!needle)
        return true
    return containsNormalized(command.label, needle)
        || containsNormalized(command.description, needle)
        || containsNormalized(command.keywords, needle)
}

function commandItem(command, index) {
    var label = command.label == null ? "" : String(command.label)
    var description = command.description == null ? "" : String(command.description)
    return {
        id: command.id == null ? "builtin-" + index : String(command.id),
        kind: "command",
        displayName: label,
        description: description,
        searchText: normalizeText(label + " " + description + " "
                                  + (command.keywords == null ? "" : String(command.keywords))).toLowerCase(),
        icon: command.icon == null ? "" : String(command.icon),
        actionId: command.actionId == null ? "" : String(command.actionId),
        managedByShell: true,
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
    var commands = Array.isArray(config.commands) ? config.commands : []
    var actionRunner = typeof config.actionRunner === "function" ? config.actionRunner : null
    var ipcHelperPath = config.ipcHelperPath == null ? "" : String(config.ipcHelperPath)

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

    return {
        refresh: function(queryText, modeName, done) {
            if (typeof done !== "function")
                return
            var values = entryValues()
            if (!values) {
                done({ error: "application source unavailable" })
                return
            }
            var needle = normalizeText(queryText).toLowerCase()
            console.log("[DEBUG-rs3] appsPull values=" + values.length)
            var out = []
            for (var index = 0; index < values.length; index++) {
                var entry = values[index]
                if (!entry || entry.noDisplay)
                    continue
                if (!appMatches(entry, needle))
                    continue
                out.push(appItem(entry, launchCounts, iconResolver))
            }
            for (var commandIndex = 0; commandIndex < commands.length; commandIndex++) {
                var candidate = commands[commandIndex]
                if (!candidate || !commandMatches(candidate, needle))
                    continue
                out.push(commandItem(candidate, commandIndex))
            }
            done(out)
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

function clipboardItem(raw) {
    var preview = raw.preview == null ? "" : String(raw.preview)
    var isImage = !!raw.isImage
    var mime = raw.mime == null ? "text/plain" : String(raw.mime)
    var seenMs = toCount(raw.firstSeenMs)
    var title = isImage ? "[Image]" : (normalizeText(preview).length ? preview : "(empty)")
    var description = mime
    var seen = timeLabel(seenMs)
    if (seen)
        description += " · copied " + seen
    return {
        id: raw.id == null ? "" : String(raw.id),
        displayName: title,
        description: description,
        searchText: normalizeText(title + " " + description).toLowerCase(),
        icon: "",
        previewText: preview,
        mime: mime,
        isImage: isImage,
        time: seenMs,
        favoriteWeight: 0,
        lastUsedAt: seenMs
    }
}

function mapClipboardItems(items, needle) {
    var out = []
    for (var index = 0; index < items.length; index++) {
        var raw = items[index]
        if (!raw)
            continue
        if (needle && !containsNormalized(raw.preview, needle))
            continue
        out.push(clipboardItem(raw))
    }
    return out
}

// Cliphist-backed clipboard history: write-back copies the selected entry;
// the very first fetch may still be in flight, so the initial refresh waits
// once for listCompletion instead of reporting an empty history.
function createClipboardAdapter(config) {
    config = config || {}
    var backend = config.clipboardBackend || null
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
            pending.done(mapClipboardItems(Array.isArray(backend.items) ? backend.items : [], pending.needle))
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
                done(mapClipboardItems(items, needle))
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

function mapShortcutItems(rows, needle) {
    var out = []
    for (var index = 0; index < rows.length; index++) {
        if (!shortcutMatches(rows[index], needle))
            continue
        out.push(shortcutItem(rows[index], index))
    }
    return out
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

    function evaluate(needle, done) {
        var rows = modelRows(backend.shortcutsModel)
        if (!rows.length && backend.errorText) {
            done({ error: String(backend.errorText) })
            return
        }
        done(mapShortcutItems(rows, needle))
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
            commands: config.commands,
            actionRunner: config.actionRunner,
            ipcHelperPath: config.ipcHelperPath
        }),
        clipboard: createClipboardAdapter({
            clipboardBackend: config.clipboardBackend || null
        }),
        shortcuts: createShortcutsAdapter({
            shortcutsBackend: config.shortcutsBackend || null,
            actionRunner: config.actionRunner || null,
            ipcHelperPath: config.ipcHelperPath || ""
        })
    }
}
