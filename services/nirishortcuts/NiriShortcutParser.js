.pragma library

function _isWhitespace(char) {
    return char === " " || char === "\t" || char === "\n" || char === "\r"
}

function _skipLineComment(text, index, limit) {
    let nextIndex = index
    while (nextIndex < limit && text[nextIndex] !== "\n")
        nextIndex++

    return nextIndex
}

function _skipWhitespaceAndComments(text, index, limit) {
    let nextIndex = index
    while (nextIndex < limit) {
        if (_isWhitespace(text[nextIndex])) {
            nextIndex++
            continue
        }

        if (text[nextIndex] === "/" && text[nextIndex + 1] === "/") {
            nextIndex = _skipLineComment(text, nextIndex, limit)
            continue
        }

        break
    }

    return nextIndex
}

function _findMatchingBrace(text, braceIndex, limit) {
    let depth = 0
    let inString = false
    let escapeNext = false

    for (let index = braceIndex; index < limit; index++) {
        const char = text[index]
        const nextChar = text[index + 1]

        if (inString) {
            if (escapeNext) {
                escapeNext = false
            } else if (char === "\\") {
                escapeNext = true
            } else if (char === '"') {
                inString = false
            }

            continue
        }

        if (char === "/" && nextChar === "/") {
            index = _skipLineComment(text, index, limit)
            continue
        }

        if (char === '"') {
            inString = true
            continue
        }

        if (char === "{") {
            depth++
            continue
        }

        if (char !== "}")
            continue

        depth--
        if (depth === 0)
            return index
    }

    return -1
}

// Every `binds { }` block in the text, in order.
//
// A file may hold more than one - niri merges includes, and the shell writes a
// second block of its own into `afloat-hotkeys.kdl` - so "the binds block" is
// not a thing a parser can look for once. Reading only the first silently
// dropped every bind after it, which is invisible until something asks which
// action a key is bound to.
function _findBindsBlocks(text) {
    const blocks = []
    const pattern = /(^|\n)\s*binds\s*\{/g
    let match = pattern.exec(text)
    while (match) {
        const braceIndex = text.indexOf("{", match.index)
        if (braceIndex < 0)
            break

        const closeIndex = _findMatchingBrace(text, braceIndex, text.length)
        if (closeIndex < 0)
            break

        blocks.push({
            bodyStart: braceIndex + 1,
            bodyEnd: closeIndex
        })
        pattern.lastIndex = closeIndex + 1
        match = pattern.exec(text)
    }

    return blocks
}

function _extractOverlayTitle(prefixText) {
    const titleMatch = /hotkey-overlay-title\s*=\s*(null|"(?:[^"\\]|\\.)*")/.exec(prefixText)
    if (!titleMatch)
        return ""

    if (titleMatch[1] === "null")
        return ""

    return titleMatch[1].slice(1, -1)
}

// Collapses whitespace BETWEEN tokens, never inside a quoted string: a spawn
// argument is a path, and a path with its spaces collapsed is a different path.
function _normalizeActionBody(actionBody) {
    const text = String(actionBody || "")
    let result = ""
    let pendingSpace = false
    let inString = false
    let escapeNext = false

    for (let index = 0; index < text.length; index++) {
        const char = text[index]
        if (inString) {
            result += char
            if (escapeNext)
                escapeNext = false
            else if (char === "\\")
                escapeNext = true
            else if (char === "\"")
                inString = false
            continue
        }

        if (char === "\"") {
            if (pendingSpace && result !== "")
                result += " "
            pendingSpace = false
            inString = true
            result += char
            continue
        }

        if (char === " " || char === "\t" || char === "\n" || char === "\r") {
            pendingSpace = true
            continue
        }

        if (pendingSpace && result !== "")
            result += " "
        pendingSpace = false
        result += char
    }

    return result.trim()
}

function _extractActionSummary(actionBody) {
    const normalized = _normalizeActionBody(actionBody)
    if (normalized === "")
        return ""

    // Split on a `;` that is not inside a quoted string, and with no regex.
    //
    // `split(";")` here, then `replace(/\s+/g, " ")` above, together ate the
    // escape characters of every quoted argument: a spawn whose path held
    // `_` came out as a path with spaces (`.../Quickshell/afloat` ->
    // `.../Quickshell afloat`). Both are now character walks.
    let inString = false
    let escapeNext = false
    let firstStatement = ""
    for (let index = 0; index < normalized.length; index++) {
        const char = normalized[index]
        if (inString) {
            if (escapeNext)
                escapeNext = false
            else if (char === "\\")
                escapeNext = true
            else if (char === "\"")
                inString = false
            firstStatement += char
            continue
        }

        if (char === "\"") {
            inString = true
            firstStatement += char
            continue
        }

        if (char === ";")
            break

        firstStatement += char
    }

    firstStatement = firstStatement.trim()
    return firstStatement === "" ? normalized : firstStatement
}

// No wording here: the parser stays language-free so its output is stable
// data, and the shell names an unnamed action at render time (see
// NiriShortcutService).
//
// The dashes become spaces for READING (`focus-column-left`), and only outside
// quoted arguments: an argument is a path, an app id or a shell command, and
// `Quickshell/afloat` spelled with a space is not the path that was written.
function _prettyActionLabel(actionSummary) {
    if (!actionSummary)
        return ""

    let result = ""
    let inString = false
    let escapeNext = false
    for (let index = 0; index < actionSummary.length; index++) {
        const char = actionSummary[index]
        if (inString) {
            result += char
            if (escapeNext)
                escapeNext = false
            else if (char === "\\")
                escapeNext = true
            else if (char === "\"")
                inString = false
            continue
        }

        if (char === "\"") {
            inString = true
            result += char
            continue
        }

        result += (char === "-" || char === "_") ? " " : char
    }

    return result
}

function _extractShellIpcActionId(normalized) {
    const ipcMatch = /ipc\s+call\s+"?([a-z0-9_-]+)"?\s+"?([a-z0-9_-]+)"?/i.exec(normalized)
    if (ipcMatch)
        return "shell." + ipcMatch[1] + "." + ipcMatch[2]

    const helperMatch = /afloat-ipc"?\s+"?([a-z0-9_-]+)"?(?:\s+"?([a-z0-9_-]+)"?)?/i.exec(normalized)
    if (helperMatch) {
        if (helperMatch[2])
            return "shell." + helperMatch[1] + "." + helperMatch[2]

        return "shell.launcher." + helperMatch[1]
    }

    if (normalized.indexOf("afloat-ipc\" \"toggle") >= 0)
        return "shell.launcher.toggle"
    if (normalized.indexOf("afloat-ipc\" \"openclipboard") >= 0)
        return "shell.launcher.openClipboard"
    if (normalized.indexOf("afloat-ipc\" \"openshortcuts") >= 0)
        return "shell.launcher.openShortcuts"
    if (normalized.indexOf("afloat-ipc\" \"settings\" \"toggle") >= 0)
        return "shell.settings.toggle"

    return ""
}

function _actionIdForBody(actionBody) {
    const normalized = _normalizeActionBody(actionBody).toLowerCase()
    const shellIpcActionId = _extractShellIpcActionId(normalized)
    if (shellIpcActionId !== "")
        return shellIpcActionId

    if (normalized.indexOf("launcher.toggle") >= 0)
        return "shell.launcherToggle"
    if (normalized.indexOf("launcher.openclipboard") >= 0)
        return "shell.launcherClipboard"
    if (normalized.indexOf("show-hotkey-overlay") >= 0)
        return "niri.showHotkeyOverlay"
    if (normalized.indexOf("toggle-overview") >= 0)
        return "niri.toggleOverview"
    if (normalized.indexOf("close-window") >= 0)
        return "niri.closeWindow"

    return ""
}

function _categoryForAction(actionSummary, actionId) {
    const normalized = String(actionSummary || "").toLowerCase()
    if (actionId.indexOf("shell.") === 0)
        return "shell"
    if (normalized.indexOf("workspace") >= 0)
        return "workspaces"
    if (normalized.indexOf("monitor") >= 0 || normalized.indexOf("output") >= 0)
        return "display"
    if (normalized.indexOf("spawn") === 0)
        return "apps"
    if (normalized.indexOf("focus-") === 0
            || normalized.indexOf("move-") === 0
            || normalized.indexOf("toggle-window") === 0
            || normalized.indexOf("switch-focus-between-floating-and-tiling") === 0
            || normalized.indexOf("consume-") === 0
            || normalized.indexOf("expel-") === 0
            || normalized.indexOf("maximize-") === 0
            || normalized.indexOf("center-") === 0
            || normalized.indexOf("set-column-width") === 0
            || normalized.indexOf("set-window-height") === 0
            || normalized.indexOf("switch-preset-") === 0
            || normalized.indexOf("reset-window-height") === 0)
        return "windows"
    if (normalized.indexOf("screenshot") === 0
            || normalized.indexOf("power-off-monitors") === 0
            || normalized.indexOf("toggle-keyboard-shortcuts-inhibit") === 0
            || normalized.indexOf("show-hotkey-overlay") === 0
            || normalized.indexOf("quit") === 0)
        return "system"

    return "other"
}

function parseShortcutEntries(text) {
    const sourceText = String(text || "")
    const blocks = _findBindsBlocks(sourceText)
    if (!blocks.length)
        return []

    const entries = []
    for (let blockIndex = 0; blockIndex < blocks.length; blockIndex++)
        _parseBindsBlock(sourceText, blocks[blockIndex], entries)

    return entries
}

// Parses the binds in ONE block, appending to `entries`. Split out so a text
// with several blocks is read by the same loop rather than by a second copy of
// it, and so the entry ids stay unique across blocks (`hotkeyStart` is an
// absolute offset, so they already are).
function _parseBindsBlock(sourceText, bindsBlock, entries) {
    let cursor = bindsBlock.bodyStart

    while (cursor < bindsBlock.bodyEnd) {
        cursor = _skipWhitespaceAndComments(sourceText, cursor, bindsBlock.bodyEnd)
        if (cursor >= bindsBlock.bodyEnd)
            break

        const hotkeyStart = cursor
        while (cursor < bindsBlock.bodyEnd && !_isWhitespace(sourceText[cursor]) && sourceText[cursor] !== "{")
            cursor++

        const hotkeyEnd = cursor
        const sequence = sourceText.slice(hotkeyStart, hotkeyEnd).trim()
        if (sequence === "") {
            cursor++
            continue
        }

        while (cursor < bindsBlock.bodyEnd && sourceText[cursor] !== "{") {
            if (sourceText[cursor] === "/" && sourceText[cursor + 1] === "/") {
                cursor = _skipLineComment(sourceText, cursor, bindsBlock.bodyEnd)
                break
            }

            cursor++
        }

        if (cursor >= bindsBlock.bodyEnd || sourceText[cursor] !== "{")
            continue

        const actionStart = cursor
        const actionEnd = _findMatchingBrace(sourceText, actionStart, bindsBlock.bodyEnd)
        if (actionEnd < 0)
            break

        let nodeEnd = actionEnd + 1
        while (nodeEnd < bindsBlock.bodyEnd && sourceText[nodeEnd] !== "\n")
            nodeEnd++
        if (nodeEnd < bindsBlock.bodyEnd)
            nodeEnd++

        const prefixText = sourceText.slice(hotkeyEnd, actionStart)
        const actionBody = sourceText.slice(actionStart + 1, actionEnd)
        const actionSummary = _extractActionSummary(actionBody)
        const actionId = _actionIdForBody(actionBody)
        const overlayTitle = _extractOverlayTitle(prefixText)

        entries.push({
            id: "shortcut-" + entries.length + "-" + hotkeyStart,
            hotkeyStart: hotkeyStart,
            hotkeyEnd: hotkeyEnd,
            nodeEnd: nodeEnd,
            sequence: sequence,
            title: overlayTitle !== "" ? overlayTitle : _prettyActionLabel(actionSummary),
            // The NAME the user wrote for this key, when they wrote one. Kept
            // beside `title` because the two mean different things: a title from
            // the file is the user's own wording and must be shown as-is, while
            // `title`'s fallback is the action body prettified, which the shell
            // names at render time (see `NiriActionLabel.js`).
            overlayTitle: overlayTitle,
            detail: actionSummary,
            actionId: actionId,
            category: _categoryForAction(actionSummary, actionId),
            managedByShell: actionId.indexOf("shell.") === 0
        })

        cursor = nodeEnd
    }
}

function applySequence(text, entries, entryId, nextSequence) {
    const sourceText = String(text || "")
    const normalizedSequence = String(nextSequence || "").trim()
    if (normalizedSequence === "")
        return sourceText

    for (let index = 0; index < entries.length; index++) {
        const entry = entries[index]
        if (!entry || entry.id !== entryId)
            continue

        return sourceText.slice(0, entry.hotkeyStart)
            + normalizedSequence
            + sourceText.slice(entry.hotkeyEnd)
    }

    return sourceText
}

// Same parse, but over several files, in the order niri merges them.
//
// `sources` is `[{ path, text }]`. Entry ids stay unique because each source's
// absolute offsets are prefixed with its index. This is what a live key lookup
// needs: the binds the user presses live in `binds.kdl` AND in the shell's own
// `afloat-hotkeys.kdl`, and an include list read out of `config.kdl` is the only
// thing that says which of them are live.
function parseShortcutEntriesFromSources(sources) {
    const list = Array.isArray(sources) ? sources : []
    const entries = []
    for (let sourceIndex = 0; sourceIndex < list.length; sourceIndex++) {
        const source = list[sourceIndex] || {}
        const text = String(source.text || "")
        const blocks = _findBindsBlocks(text)
        const blockEntries = []
        for (let blockIndex = 0; blockIndex < blocks.length; blockIndex++)
            _parseBindsBlock(text, blocks[blockIndex], blockEntries)

        for (let index = 0; index < blockEntries.length; index++) {
            const entry = blockEntries[index]
            entry.id = "s" + sourceIndex + "-" + entry.id
            entry.sourcePath = String(source.path || "")
            entries.push(entry)
        }
    }

    return entries
}
