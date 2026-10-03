.pragma library

// Reveal timing for the wallpaper disc: the boot open and a live switch are two
// different contracts, so the decision lives here rather than inline in the
// component where nothing can test it.
//
// The boot reveal's DURATION is DymicShell's: `Math.round(3000 / speedFactor)` at
// its default speedFactor of 1.0
// (DymicShell/modules/background/BackgroundWindow.qml). Long on purpose — it lets
// the shell finish mounting underneath the circle instead of being caught
// mid-reveal. Reference: DymicShell, MIT.
//
// Its CURVE is not DymicShell's. That shell eases back off at the end
// (InOutSine), which reads as the transition settling; this one accelerates all
// the way out (InQuad), so the open commits rather than lands. The value is
// supplied by the caller as a token — see MotionTokens.wallpaperBootRevealEasing —
// so the curve is stated once and both this module and the test read it.
//
// A live switch keeps the shell's own snappier contract: the user asked for that
// wallpaper and is waiting on the result, so it should not crawl open for three
// seconds.

// Only a live boot reveal counts as one. Anything else — undefined, null, a
// stale value read mid-handover — reads as a switch, which is the conservative
// answer: the fast path never leaves the user waiting.
function isBootReveal(isBoot) {
    return isBoot === true
}

function revealDuration(isBoot, bootDuration, swapDuration) {
    return isBootReveal(isBoot) ? bootDuration : swapDuration
}

function revealEasing(isBoot, bootEasing, swapEasing) {
    return isBootReveal(isBoot) ? bootEasing : swapEasing
}
