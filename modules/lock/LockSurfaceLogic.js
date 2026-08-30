.pragma library

// Cap the rendered mask so a runaway buffer can never inflate the surface.
var maxMaskedCharacters = 32
var maskCharacter = "\u25CF"

function stopAnimations(enterAnimation, exitAnimation) {
    enterAnimation.stop()
    exitAnimation.stop()
}

// Render the live password as fixed-size bullets without ever exposing it.
function maskedPassword(text) {
    var length = String(text || "").length
    if (length <= 0)
        return ""
    var visible = Math.min(length, maxMaskedCharacters)
    var masked = ""
    for (var i = 0; i < visible; ++i)
        masked += maskCharacter
    return masked
}

// Choose the visible status line and its tone for the current auth state.
// An empty PAM message still surfaces a spoken failure instead of silence.
var authTones = {
    none: "none",
    progress: "progress",
    failure: "failure"
}

function authStatus(unlockInProgress, showFailure, errorMessage) {
    if (unlockInProgress === true)
        return { message: "Verifying...", tone: authTones.progress }
    if (showFailure === true)
        return { message: String(errorMessage || "") || "Authentication failed", tone: authTones.failure }
    return { message: "", tone: authTones.none }
}

// Resolve a surface's snapshot slot from the shared screen list; an unknown
// screen resolves to no slot instead of another screen's image.
function screenSlot(screens, screen) {
    if (!screens || !screen)
        return -1
    for (var i = 0; i < screens.length; ++i) {
        if (screens[i] === screen)
            return i
    }
    return -1
}

function applyRevealImmediately(surface, enterAnimation, exitAnimation) {
    stopAnimations(enterAnimation, exitAnimation)
    surface.waveProgress = 1
    surface.authOpacity = 1
}

function applyExitImmediately(surface, enterAnimation, exitAnimation) {
    stopAnimations(enterAnimation, exitAnimation)
    surface.waveProgress = 0
    surface.authOpacity = 0
}
