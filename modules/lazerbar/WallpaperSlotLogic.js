.pragma library

// Two reusable wallpaper image slots, so a switch promotes the wallpaper that is
// already decoded instead of handing its pixels to a second full-screen image.
// Pure JS so slot roles and decode sizes stay testable without a window.

// Only two slots exist, so a role is either 0 or 1 and nothing else is a role.
function isSlot(value) {
    return value === 0 || value === 1
}

// Fallback texture budget for one full-screen decode when none is configured.
var DefaultMaxTexturePixels = 16 * 1024 * 1024

function finite(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

function slotOr(value, fallback) {
    return isSlot(value) ? value : fallback
}

// The other slot. Anything that is not slot 0 reads as "not slot 0", so an
// unreadable role fails closed onto slot 0 rather than onto itself.
function otherSlot(slot) {
    return slot === 0 ? 1 : 0
}

// Swap the roles so the freshly decoded incoming wallpaper becomes the settled
// one. Only the roles move: the caller must not reassign the newly settled
// image's source, because its pixels are already there.
//
// Two distinct real slots promote. A readable equal pair is already what the
// caller holds and is returned as it is. When a role cannot be read there is
// nothing to promote, so the settled role stays put (defaulting to slot 0) and
// the incoming role takes the other slot — the pair that comes back always holds
// two real roles.
function promote(settledSlot, incomingSlot) {
    if (isSlot(settledSlot) && isSlot(incomingSlot)) {
        if (settledSlot === incomingSlot)
            return { settledSlot: settledSlot, incomingSlot: incomingSlot }
        return { settledSlot: incomingSlot, incomingSlot: settledSlot }
    }
    var settled = slotOr(settledSlot, 0)
    return { settledSlot: settled, incomingSlot: slotOr(incomingSlot, otherSlot(settled)) }
}

// Decode size for one wallpaper: the screen at its device pixel ratio, shrunk
// until it fits the texture budget. Returns whole pixels and never zero, so a
// caller can assign the result to an Image directly.
function sourceSize(screenWidth, screenHeight, devicePixelRatio, maxTexturePixels) {
    // A ratio below one would decode fewer pixels than the screen has, which
    // buys blur instead of memory.
    var ratio = Math.max(1, finite(devicePixelRatio, 1))
    var width = Math.max(1, Math.floor(finite(screenWidth, 0) * ratio))
    var height = Math.max(1, Math.floor(finite(screenHeight, 0) * ratio))
    // An unusable cap falls back to the default budget rather than collapsing
    // the wallpaper to a single pixel.
    var budget = Math.floor(finite(maxTexturePixels, DefaultMaxTexturePixels))
    if (!(budget > 0))
        budget = DefaultMaxTexturePixels
    if (width * height <= budget)
        return { width: width, height: height }
    // One factor for both sides, so the wallpaper keeps its aspect ratio and the
    // longer side is what gives way. Floor, not round: a decode request must
    // never come out larger than the bound it is being clamped to.
    var scale = Math.sqrt(budget / (width * height))
    width = Math.max(1, Math.floor(width * scale))
    height = Math.max(1, Math.floor(height * scale))
    // Rounding the scaled pair can still land a hair over the budget, so trim
    // the longer side until the product really fits.
    while (width * height > budget) {
        if (width >= height && width > 1)
            width -= 1
        else if (height > 1)
            height -= 1
        else
            break
    }
    return { width: width, height: height }
}
