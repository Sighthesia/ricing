.pragma library

// Cap the rendered mask so a runaway buffer can never inflate the surface.
var maxMaskedCharacters = 32
var maskCharacter = "\u25CF"

// Background modes the surface understands. The default (and any unknown
// value) captures the desktop before locking; "wallpaper" skips the capture
// and reveals the wallpaper over the opaque floor instead.
var backgroundModes = {
    wallpaper: "wallpaper",
    screenshot: "screenshot"
}

function normalizeBackgroundMode(mode) {
    return mode === backgroundModes.wallpaper ? backgroundModes.wallpaper : backgroundModes.screenshot
}

// The base layer shows this screen's pre-lock capture immediately; without
// one, the opaque floor covers the desktop instead.
function baseSource(snapshotUrl) {
    return snapshotUrl || ""
}

// The reveal layer is the wallpaper the wave mask uncovers as it sweeps.
function revealSource(wallpaperPath) {
    return wallpaperPath || ""
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
    surface.authOpacity = 1
}

function applyExitImmediately(surface, animations) {
    stopAll(animations)
    surface.waveProgress = 0
    surface.authOpacity = 0
}
