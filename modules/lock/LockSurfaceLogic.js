.pragma library

// Cap the rendered mask so a runaway buffer can never inflate the surface.
var maxMaskedCharacters = 32
var maskCharacter = "\u25CF"

// Background modes the surface understands; unknown values resolve to wallpaper.
var backgroundModes = {
    wallpaper: "wallpaper",
    screenshot: "screenshot"
}

function normalizeBackgroundMode(mode) {
    return mode === backgroundModes.screenshot ? backgroundModes.screenshot : backgroundModes.wallpaper
}

// Pick the artwork the wave curtain reveals: a screenshot only when its own
// capture actually produced a URL, otherwise the configured wallpaper, and
// otherwise nothing (the body's opaque floor covers the desktop instead).
function backgroundSource(mode, snapshotUrl, wallpaperPath) {
    var normalized = normalizeBackgroundMode(mode)
    if (normalized === backgroundModes.screenshot && snapshotUrl)
        return snapshotUrl
    if (wallpaperPath)
        return wallpaperPath
    return normalized === backgroundModes.screenshot ? (snapshotUrl || "") : ""
}

function stopAll(animations) {
    if (!animations)
        return
    for (var i = 0; i < animations.length; ++i) {
        if (animations[i])
            animations[i].stop()
    }
}

function stopAnimations(enterAnimation, exitAnimation) {
    stopAll([enterAnimation, exitAnimation])
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

function applyRevealImmediately(surface, animations) {
    stopAll(animations)
    surface.waveProgress = 1
    surface.bodyProgress = 1
    surface.authOpacity = 1
}

function applyExitImmediately(surface, animations) {
    stopAll(animations)
    surface.waveProgress = 0
    surface.bodyProgress = 0
    surface.authOpacity = 0
}
