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

// Keep keyboard editing on one focused owner instead of handing events off to
// a native TextInput after the first key.
function passwordInputEdit(currentText, isSubmit, isBackspace, eventText) {
    var text = String(currentText || "")
    if (isSubmit)
        return { action: "submit", text: text }
    if (isBackspace)
        return { action: "edit", text: text.slice(0, -1) }
    var typed = String(eventText || "")
    if (typed.length === 1 && typed.charCodeAt(0) >= 0x20 && typed.charCodeAt(0) !== 0x7f)
        return { action: "edit", text: text + typed }
    return { action: "none", text: text }
}

// Authentication control states keep the icon visible through input expansion
// and provide a short success state before the compositor surface exits.
var AuthControlStates = {
    idle: "idle",
    input: "input",
    unlocked: "unlocked"
}

function authControlTransition(state, event) {
    if (event === "enter-input")
        return AuthControlStates.input
    if (event === "auth-success")
        return AuthControlStates.unlocked
    if (event === "reset" || event === "auth-failure")
        return AuthControlStates.idle
    return state
}

// Keep lock-surface text readable while preserving the active wallpaper hue.
// Theme files are reloaded asynchronously, so transparent/black intermediate
// values must never reach a visible lock label.
function readableThemeColor(accent, lightScheme) {
    var hue = Number(accent && accent.hslHue)
    var saturation = Number(accent && accent.hslSaturation)
    var alpha = Number(accent && accent.a)
    if (!isFinite(hue) || !isFinite(saturation) || !isFinite(alpha) || alpha < 0.5
            || saturation < 0.08) {
        hue = 0.72
        saturation = 0.65
    }
    saturation = Math.max(0.42, Math.min(0.86, saturation))
    return Qt.hsla(hue, saturation, lightScheme === true ? 0.28 : 0.76, 1)
}

// Use a separate extreme tonal role for password/status text so it remains
// distinct from the accent-toned icon while keeping the wallpaper hue.
function readableTextColor(accent, lightScheme) {
    var iconColor = readableThemeColor(accent, lightScheme)
    return Qt.hsla(iconColor.hslHue, iconColor.hslSaturation,
        lightScheme === true ? 0.16 : 0.90, 1)
}

// Pick a readable tonal variant of the wallpaper-derived accent without
// falling back to unrelated pure white or pure black text.
function clockThemeColor(accent, backgroundLuminance, lightScheme) {
    return readableThemeColor(accent, lightScheme)
}

function clockThemeMutedColor(accent, backgroundLuminance, lightScheme) {
    var main = clockThemeColor(accent, backgroundLuminance, lightScheme)
    var lightness = lightScheme === true ? 0.40 : 0.64
    return Qt.hsla(main.hslHue, main.hslSaturation, lightness, 1)
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
