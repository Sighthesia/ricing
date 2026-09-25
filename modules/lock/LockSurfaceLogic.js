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

// The reveal layer is the pinned wallpaper the trailing mask unveils at
// the band tail. No configured wallpaper resolves to nothing; the settled
// bands then keep showing over the screenshot instead of a flat panel color.
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

// Escape may cancel only the local authentication presentation; it never
// releases the compositor lock.
function inputEscapeAction(inputMode, unlockInProgress) {
    return inputMode === true || unlockInProgress === true ? "cancel-input" : "none"
}

// Derive the trailing foreground reveal from the wave's shared progress.
// Keeping this pure makes the lock entrance timing testable without Wayland.
function trailingRevealProgress(progress, delay) {
    var safeProgress = Math.max(0, Math.min(1, Number(progress) || 0))
    var safeDelay = Math.max(0, Math.min(0.99, Number(delay) || 0))
    return Math.max(0, Math.min(1, (safeProgress - safeDelay) / (1 - safeDelay)))
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
}

function applyExitImmediately(surface, animations) {
    stopAll(animations)
    surface.waveProgress = 0
}
