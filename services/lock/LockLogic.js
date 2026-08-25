.pragma library

// Pure lock-session contracts: key classification, password buffer edits,
// and PAM outcome mapping. No Quickshell objects so the whole file runs
// under qmltestrunner without a compositor.

var keyEscape = 0x01000000
var keyBackspace = 0x01000003
var keyReturn = 0x01000004
var keyEnter = 0x01000005

var maxBufferSize = 512

// Classify one key event snapshot into an edit intent.
function keyAction(keyCode, hasControlModifier) {
    var code = Number(keyCode)
    if (code === keyReturn || code === keyEnter)
        return "submit"
    if (code === keyBackspace)
        return hasControlModifier ? "clear" : "backspace"
    return "input"
}

// Apply an edit intent to the shared buffer, returning the next buffer plus
// what happened: "submit", "changed", or "ignored".
function applyKey(buffer, keyCode, text, hasControlModifier) {
    var current = buffer == null ? "" : String(buffer)
    var action = keyAction(keyCode, hasControlModifier)
    if (action === "submit")
        return { action: "submit", buffer: current }
    if (action === "clear")
        return current.length ? { action: "changed", buffer: "" } : { action: "ignored", buffer: current }
    if (action === "backspace") {
        if (!current.length)
            return { action: "ignored", buffer: current }
        return { action: "changed", buffer: current.slice(0, -1) }
    }
    // Printable input only: reject control characters outright.
    if (!text || !/^[^\x00-\x1F\x7F-\x9F]+$/.test(text))
        return { action: "ignored", buffer: current }
    if (current.length >= maxBufferSize)
        return { action: "ignored", buffer: current }
    return { action: "changed", buffer: current + String(text) }
}

// Whether a submit attempt may start PAM with the given buffer state.
function canAttemptSubmit(buffer, unlockInProgress) {
    return !!buffer && !!buffer.length && !unlockInProgress
}

// Map a PamContext completion result onto the surface feedback state.
// Numeric inputs keep this usable from tests without importing the Pam module.
function outcomeState(result, successResult, maxTriesResult, errorResult) {
    var code = Number(result)
    if (code === Number(successResult))
        return "success"
    if (code === Number(maxTriesResult))
        return "maxTries"
    if (code === Number(errorResult))
        return "error"
    return "failed"
}
