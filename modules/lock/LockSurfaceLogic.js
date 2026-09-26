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
// values must never reach a visible lock label. The fallback follows Afloat's
// osu-pink accent rather than an arbitrary violet hue.
function readableThemeColor(accent, lightScheme) {
    var hue = Number(accent && accent.hslHue)
    var saturation = Number(accent && accent.hslSaturation)
    var alpha = Number(accent && accent.a)
    if (!isFinite(hue) || !isFinite(saturation) || !isFinite(alpha) || alpha < 0.5
            || saturation < 0.08) {
        hue = 0.93
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

function _usableColor(color) {
    return !!color && isFinite(Number(color.a)) && Number(color.a) >= 0.5
            && (Number(color.r) + Number(color.g) + Number(color.b)) > 0.02
}

function _nearColor(first, second) {
    if (!_usableColor(first))
        return false
    return Math.abs(Number(first.r) - Number(second.r)) < 0.015
        && Math.abs(Number(first.g) - Number(second.g)) < 0.015
        && Math.abs(Number(first.b) - Number(second.b)) < 0.015
}

function _modeSurface(candidate, lightScheme, fallback) {
    if (!_usableColor(candidate))
        return fallback
    var lightness = Number(candidate.hslLightness)
    if (!isFinite(lightness) || (lightScheme === true ? lightness < 0.5 : lightness > 0.5))
        return fallback
    return candidate
}

// Freeze all lock-surface colors for one lock cycle. This prevents each child
// from sampling a different frame of Color.qml's animated palette transition.
function lockThemeSnapshot(lightScheme, palette) {
    var light = lightScheme === true
    var fallbackAccent = Qt.rgba(1, 0.4, 0.667, 1)
    var rawAccent = palette ? palette.accent : null
    // These are Afloat's built-in fallback accents, not wallpaper results.
    if (!_usableColor(rawAccent) || _nearColor(rawAccent, Qt.rgba(0.463, 0.357, 1, 1))
            || _nearColor(rawAccent, Qt.rgba(0.784, 0.749, 1, 1)))
        rawAccent = fallbackAccent

    var surfaceFallback = light ? "#F2F0F5" : "#18171C"
    var controlFallback = light ? "#EEEAF1" : "#25222E"
    var mutedFallback = light ? "#5F5A66" : "#B8B4BC"
    var dividerFallback = light ? "#C9C4CE" : "#2E2C32"
    var surface = _modeSurface(palette && palette.surface, light, surfaceFallback)
    var control = _modeSurface(palette && palette.control, light, controlFallback)
    var muted = _usableColor(palette && palette.muted) ? palette.muted : mutedFallback
    var divider = _usableColor(palette && palette.divider) ? palette.divider : dividerFallback
    var panel = _usableColor(palette && palette.panel) ? palette.panel : surface
    var trigger = _usableColor(palette && palette.trigger) ? palette.trigger : control
    var active = _usableColor(palette && palette.active) ? palette.active : trigger
    return {
        lightScheme: light,
        accent: rawAccent,
        surface: surface,
        control: control,
        panel: panel,
        trigger: trigger,
        active: active,
        muted: muted,
        divider: divider,
        text: readableTextColor(rawAccent, light),
        icon: readableThemeColor(rawAccent, light),
        sessionText: readableThemeColor(rawAccent, light),
        clock: readableThemeColor(rawAccent, light),
        clockMuted: clockThemeMutedColor(rawAccent, 0.5, light)
    }
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
