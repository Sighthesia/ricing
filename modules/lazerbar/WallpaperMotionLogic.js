.pragma library

// Reveal timing for the wallpaper disc: the boot open and a live switch are two
// different contracts, so the decision lives here rather than inline in the
// component where nothing can test it.
//
// The boot reveal follows DymicShell's background window
// (DymicShell/modules/background/BackgroundWindow.qml): `Easing.InOutSine` over
// `Math.round(3000 / speedFactor)` with its default speedFactor of 1.0. That is
// deliberately slow and soft — the point is to open gently over whatever the
// shell is still mounting, rather than to draw attention to the transition.
// Reference: DymicShell, MIT.
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
