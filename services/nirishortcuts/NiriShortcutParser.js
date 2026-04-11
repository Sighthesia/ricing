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

function _findBindsBlock(text) {
    const bindsMatch = /(^|\n)\s*binds\s*\{/m.exec(text)
    if (!bindsMatch)
        return null

    const braceIndex = text.indexOf("{", bindsMatch.index)
    if (braceIndex < 0)
        return null

    const closeIndex = _findMatchingBrace(text, braceIndex, text.length)
    if (closeIndex < 0)
        return null

    return {
        bodyStart: braceIndex + 1,
        bodyEnd: closeIndex
    }
}

function _extractOverlayTitle(prefixText) {
    const titleMatch = /hotkey-overlay-title\s*=\s*(null|"(?:[^"\\]|\\.)*")/.exec(prefixText)
    if (!titleMatch)
        return ""

    if (titleMatch[1] === "null")
        return ""

    return titleMatch[1].slice(1, -1)
}

function _normalizeActionBody(actionBody) {
    return String(actionBody || "").replace(/\s+/g, " ").trim()
}

function _extractActionSummary(actionBody) {
    const normalized = _normalizeActionBody(actionBody)
    if (normalized === "")
        return ""

    const firstStatement = normalized.split(";")[0].trim()
    if (firstStatement === "")
        return normalized

    return firstStatement
}

function _prettyActionLabel(actionSummary) {
    if (!actionSummary)
        return "未命名快捷键"

    return actionSummary.replace(/[-_]/g, " ")
}

function _extractShellIpcActionId(normalized) {
    const ipcMatch = /ipc\s+call\s+"?([a-z0-9_-]+)"?\s+"?([a-z0-9_-]+)"?/i.exec(normalized)
    if (ipcMatch)
        return "shell." + ipcMatch[1] + "." + ipcMatch[2]

    if (normalized.indexOf("dymicshell-ipc\" \"toggle") >= 0)
        return "shell.launcher.toggle"
    if (normalized.indexOf("dymicshell-ipc\" \"openclipboard") >= 0)
        return "shell.launcher.openClipboard"

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
    const bindsBlock = _findBindsBlock(sourceText)
    if (!bindsBlock)
        return []

    const entries = []
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
            detail: actionSummary,
            actionId: actionId,
            category: _categoryForAction(actionSummary, actionId),
            managedByShell: actionId.indexOf("shell.") === 0
        })

        cursor = nodeEnd
    }

    return entries
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
