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

// The horizontal center of the password field: the control minus the glyph
// inset on the left and the right inset. The masked bullets are centered here,
// and so is the empty-field caret, so clearing the input cannot leave the
// insertion mark sitting somewhere the text had never been.
function passwordTextAxis(controlWidth, leftInset, rightInset) {
    var left = Number(leftInset) || 0
    var right = Number(rightInset) || 0
    var width = Number(controlWidth) || 0
    return left + (width - left - right) / 2
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

// The lock surface's three content blocks. Their index order is also their
// vertical order on screen (clock, lock control, power row), which is what makes
// a delay taken from it read as a wave crossing the surface.
var contentBlocks = {
    clock: 0,
    control: 1,
    actions: 2,
    count: 3
}

// Entry and exit sample one shared curve — the notification fling's free fall
// (t²) for travel and fade — but each block reads its own delayed position on
// it, so the blocks start one after another instead of moving as one group.
//
// The delays are asymmetric on purpose. Entry counts up (clock first, power row
// last, lifting into place); exit counts down (power row first, clock last,
// dropping away), so the two directions are two different waves rather than the
// same wave played backwards. A block's delay is measured on the animation
// clock, not in progress units: `progress` runs over the whole staggered span
// (the curve plus every delay), so each block still gets the full curve length
// and every block lands exactly when the driver stops.
//
// The output is one 0..1 slot per block; callers own the travel and the fade
// shape so reduced motion and the entry lift stay call-site decisions.
function contentSlots(progress, entering, curveMs, staggerMs, blockCount) {
    var curve = Number(curveMs) > 0 ? Number(curveMs) : 0
    var step = Number(staggerMs) > 0 ? Number(staggerMs) : 0
    var count = Number(blockCount) > 0 ? Number(blockCount) : 1
    // The driver covers the curve plus the delay of the last block to start, so
    // no block is left frozen mid-travel when the animation ends.
    var span = curve + (count - 1) * step
    var t = Number(progress)
    if (!(t > 0))
        t = 0
    if (t > 1)
        t = 1
    var slots = []
    for (var i = 0; i < count; ++i) {
        // Entry: block 0 starts at 0, block n at n * step. Exit: the last block
        // starts first, so the delay is read backwards off the same step.
        var delay = (entering === true ? i : count - 1 - i) * step
        var local = curve > 0 ? (t * span - delay) / curve : 1
        if (local < 0)
            local = 0
        if (local > 1)
            local = 1
        var eased = local * local
        slots.push({ drop: eased, fade: eased })
    }
    return slots
}

// Read one block out of a slot list. A missing list or index answers the state
// before any motion started (no travel, no fade), which is the safe resting
// point for both directions: entry keeps the block hidden below its place, exit
// keeps it fully present.
function contentSlot(slots, block) {
    if (!slots || block < 0 || block >= slots.length)
        return { drop: 0, fade: 0 }
    return slots[block]
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

// The accent hue/saturation every lock role is built from. Theme files are
// reloaded asynchronously, so transparent or colourless intermediate values
// must never reach a visible lock label; the fallback follows Afloat's
// osu-pink accent rather than an arbitrary violet hue.
function _inkHueSaturation(accent) {
    var hue = Number(accent && accent.hslHue)
    var saturation = Number(accent && accent.hslSaturation)
    var alpha = Number(accent && accent.a)
    if (!isFinite(hue) || !isFinite(saturation) || !isFinite(alpha) || alpha < 0.5
            || saturation < 0.08) {
        hue = 0.93
        saturation = 0.65
    }
    saturation = Math.max(0.42, Math.min(0.86, saturation))
    return { hue: hue, saturation: saturation }
}

// Keep lock-surface text readable while preserving the active wallpaper hue.
function readableThemeColor(accent, lightScheme) {
    var ink = _inkHueSaturation(accent)
    return Qt.hsla(ink.hue, ink.saturation, lightScheme === true ? 0.28 : 0.76, 1)
}

// Use a separate extreme tonal role for password/status text so it remains
// distinct from the accent-toned icon while keeping the wallpaper hue.
function readableTextColor(accent, lightScheme) {
    var iconColor = readableThemeColor(accent, lightScheme)
    return Qt.hsla(iconColor.hslHue, iconColor.hslSaturation,
        lightScheme === true ? 0.16 : 0.90, 1)
}

// Detach a color from the binding that produced it. A color read from a
// QML property is a binding-backed value type: stored in a JS object it keeps
// re-evaluating, so an un-detached "snapshot" silently follows the live theme
// and the lock surface keeps repainting. Copying the channels into a plain
// Qt.rgba value is what actually freezes a lock cycle.
function _detach(color) {
    // Literal fallbacks are already inert; only real color values carry a
    // binding that has to be broken.
    if (typeof color === "string")
        return color
    return Qt.rgba(Number(color.r), Number(color.g), Number(color.b), Number(color.a))
}

// A tint may legitimately be nearly transparent (hover washes sit around 8%
// alpha), so fills only need a visible alpha. Surfaces and text must be solid
// enough to stay readable.
function _visibleColor(color) {
    return !!color && isFinite(Number(color.a)) && Number(color.a) > 0.02
            && (Number(color.r) + Number(color.g) + Number(color.b)) > 0.02
}

function _usableColor(color) {
    return _visibleColor(color) && Number(color.a) >= 0.5
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
//
// `clockLuminance` is the wallpaper region's measured luma under the clock.
// prepareReveal() runs before the placement cache has necessarily answered, so
// this is the *initial* snapshot; LockSurface.refreshClockTheme() re-snapshots
// the clock roles when a real measurement arrives, because the ink polarity
// depends on it and a stale 0.5 produced a fixed light clock over light regions.
function lockThemeSnapshot(lightScheme, palette, clockLuminance) {
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
    var labelFallback = light ? "#1D1B20" : "#E6E1E5"
    var hoverFallback = light ? "#141D1B20" : "#18FFFFFF"
    var muted = _usableColor(palette && palette.muted) ? palette.muted : mutedFallback
    var divider = _usableColor(palette && palette.divider) ? palette.divider : dividerFallback
    var panel = _usableColor(palette && palette.panel) ? palette.panel : surface
    var trigger = _usableColor(palette && palette.trigger) ? palette.trigger : control
    // Interactive washes are allowed to stay translucent; rejecting them would
    // silently swap a real hover/active tint for an unrelated surface color.
    var active = _visibleColor(palette && palette.active) ? palette.active : trigger
    var hover = _visibleColor(palette && palette.hover) ? palette.hover : hoverFallback
    var label = _usableColor(palette && palette.label) ? palette.label : labelFallback
    // osuPink and focusRing both track the primary in the adapting theme; keep a
    // distinct value when one is supplied, otherwise reuse the frozen accent.
    var pink = _visibleColor(palette && palette.pink) ? palette.pink : rawAccent
    var focus = _visibleColor(palette && palette.focus) ? palette.focus : rawAccent
    // Detach every accepted color: a stored binding-backed color would keep
    // tracking the animated theme and repaint this lock cycle.
    return {
        lightScheme: light,
        accent: _detach(rawAccent),
        surface: _detach(surface),
        control: _detach(control),
        panel: _detach(panel),
        trigger: _detach(trigger),
        active: _detach(active),
        hover: _detach(hover),
        label: _detach(label),
        muted: _detach(muted),
        pink: _detach(pink),
        focus: _detach(focus),
        divider: _detach(divider),
        text: _detach(readableTextColor(rawAccent, light)),
        // Row icons follow the muted ink; the lock glyph uses the accent tone.
        icon: _detach(readableThemeColor(rawAccent, light)),
        rowIcon: _detach(muted),
        sessionText: _detach(readableThemeColor(rawAccent, light)),
        // The clock is the only lock element with no surface under it, so its
        // ink follows the wallpaper region it sits on rather than the scheme.
        clock: _detach(clockThemeColor(rawAccent, clockLuminance, light))
    }
}

// Re-derive the clock role from an already-frozen accent. A placement answer
// can land after prepareReveal(), and the clock must then repaint without
// re-reading a theme that may have moved on since the cycle was frozen.
function clockRoles(accent, clockLuminance, lightScheme) {
    return {
        clock: _detach(clockThemeColor(accent, clockLuminance, lightScheme))
    }
}

// The clock is the only lock element with no surface under it, so its ink has to
// survive whatever wallpaper sits behind it. Picking one of two fixed tones was
// not enough: `backgroundLuminance` is the mean luma of the region the clock was
// placed on, and a fixed light ink at 0.76 lightness clears only ~1.3:1 against a
// bright region -- which is exactly how the clock used to dissolve into the
// wallpaper. Hue and saturation still come from the accent, but lightness is now
// solved for a contrast target against the measured region.
//
// The target is 3:1, not 4.5:1. WCAG asks 3:1 of *large* text, and this is a 72px
// Black clock -- twelve times the 18pt threshold. Aiming at the normal-text ratio
// forced the ink to near-white on any mid-tone region, and at that lightness an
// HSL colour has no chroma left: the clock stopped being the accent's colour at
// all. 3:1 is the correct standard for this size and is what keeps the hue alive.
var clockInkTarget = 3.0

// Lightness is not free: as it approaches the extreme, HSL saturation can no
// longer produce chroma, so the accent's own saturation is too timid to read at
// the lightness the target demands. Pushing saturation up buys back the hue that
// the lightness spends.
var clockInkSaturationBoost = 1.5

// Each polarity keeps a band: `soft` is the tone the accent reads best at, and
// the solver only travels towards `extreme` (white or black) as far as the target
// demands. On a dark region the clock therefore stays at its natural 0.74 rather
// than being bleached to white, and on a bright one it darkens to the exact
// lightness that clears the target instead of jumping to near-black.
var clockInkBands = {
    light: { soft: 0.74, extreme: 0.99 },
    dark: { soft: 0.32, extreme: 0.01 }
}

// sRGB channel -> linear light, the space WCAG ratios are defined in.
function _linearChannel(channel) {
    var value = Number(channel)
    if (!isFinite(value))
        return 0
    value = value < 0 ? 0 : (value > 1 ? 1 : value)
    return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
}

// HSL -> sRGB, matching Qt.hsla's hue/saturation/lightness convention. The
// solver needs the channels themselves, since contrast is quadratic in them.
function _hslChannels(hue, saturation, lightness) {
    var h = Number(hue)
    var s = Math.max(0, Math.min(1, Number(saturation)))
    var l = Math.max(0, Math.min(1, Number(lightness)))
    if (!isFinite(h))
        h = 0
    h = h - Math.floor(h)
    if (s <= 0)
        return { r: l, g: l, b: l }
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s
    var p = 2 * l - q
    function channel(offset) {
        var t = h + offset
        if (t < 0)
            t += 1
        if (t > 1)
            t -= 1
        if (t < 1 / 6)
            return p + (q - p) * 6 * t
        if (t < 1 / 2)
            return q
        if (t < 2 / 3)
            return p + (q - p) * (2 / 3 - t) * 6
        return p
    }
    return { r: channel(1 / 3), g: channel(0), b: channel(-1 / 3) }
}

// WCAG relative luminance of an HSL triple.
function _hslLuminance(hue, saturation, lightness) {
    var rgb = _hslChannels(hue, saturation, lightness)
    return 0.2126 * _linearChannel(rgb.r) + 0.7152 * _linearChannel(rgb.g)
        + 0.0722 * _linearChannel(rgb.b)
}

// The analyzer reports the region's *encoded* mean luma (cv2 RGB2GRAY / 255), so
// a measurement of 0.46 is sRGB grey 0.46, not linear 0.46. Contrast maths needs
// the linearized value, otherwise every threshold would drift bright.
function _regionLuminance(backgroundLuminance) {
    var luma = Number(backgroundLuminance)
    if (!isFinite(luma) || luma < 0)
        return -1
    return _linearChannel(luma)
}

function _contrastRatio(first, second) {
    var high = Math.max(first, second)
    var low = Math.min(first, second)
    return (high + 0.05) / (low + 0.05)
}

// Whichever extreme can put more distance between the ink and the region wins the
// polarity. Saturation matters here: a saturated hue cannot reach white, so on
// mid-tone regions a deep ink often beats a washed-out bright one. A negative or
// non-finite measurement means "no answer yet" and the scheme still decides, so a
// cold placement cache never paints an ink the wallpaper contradicts.
function clockInkPolarity(accent, backgroundLuminance, lightScheme) {
    var region = _regionLuminance(backgroundLuminance)
    if (region < 0)
        return lightScheme === true ? "dark" : "light"
    var ink = _inkHueSaturation(accent)
    var saturation = _clockSaturation(ink)
    var bright = _contrastRatio(_hslLuminance(ink.hue, saturation,
                                              clockInkBands.light.extreme), region)
    var deep = _contrastRatio(_hslLuminance(ink.hue, saturation,
                                            clockInkBands.dark.extreme), region)
    return deep > bright ? "dark" : "light"
}

// The saturation actually painted: the accent's own, raised so the hue survives
// the lightness the contrast target forces. See clockInkSaturationBoost.
function _clockSaturation(ink) {
    return Math.min(1, ink.saturation * clockInkSaturationBoost)
}

// Travel from the band's soft tone towards its extreme only until the target is
// met, then stop. Contrast improves monotonically along that path, so the binary
// search is valid; the final check keeps the answer honest if it ever is not, and
// the extreme is the best the band can do when nothing reaches the target.
function _solveInkLightness(hue, saturation, region, target, band) {
    function contrastAt(lightness) {
        return _contrastRatio(_hslLuminance(hue, saturation, lightness), region)
    }
    if (contrastAt(band.soft) >= target)
        return band.soft
    if (contrastAt(band.extreme) < target)
        return band.extreme
    var soft = band.soft
    var extreme = band.extreme
    var accepted = extreme
    for (var i = 0; i < 16; ++i) {
        var middle = (soft + extreme) / 2
        if (contrastAt(middle) >= target) {
            accepted = middle
            extreme = middle
        } else {
            soft = middle
        }
    }
    return contrastAt(accepted) >= target ? accepted : band.extreme
}

function _clockInk(accent, backgroundLuminance, lightScheme) {
    var ink = _inkHueSaturation(accent)
    var saturation = _clockSaturation(ink)
    var polarity = clockInkPolarity(accent, backgroundLuminance, lightScheme)
    var band = clockInkBands[polarity]
    var region = _regionLuminance(backgroundLuminance)
    if (region < 0)
        return Qt.hsla(ink.hue, saturation, band.soft, 1)
    return Qt.hsla(ink.hue, saturation,
                   _solveInkLightness(ink.hue, saturation, region,
                                      clockInkTarget, band), 1)
}

function clockThemeColor(accent, backgroundLuminance, lightScheme) {
    return _clockInk(accent, backgroundLuminance, lightScheme)
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
    // Reduced motion lands every block on its settled entry state: no lift, no
    // fade, and no stagger waiting behind the curtain.
    surface.entryContentProgress = 1
}

function applyExitImmediately(surface, animations) {
    stopAll(animations)
    surface.waveProgress = 0
    // Reduced motion leaves the blocks where the fall left them: dropped and
    // faded, with the closing wave passing over an already empty surface.
    surface.contentFallProgress = 1
}
