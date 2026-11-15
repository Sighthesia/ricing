.pragma library

// The bar starts slid out of its own window viewport and slides in once its
// widgets are staged, so a session has an arrival instead of a pop-in. The same
// scalar now runs the other way too: a lock photographs the desktop, so the bar
// slides back out before that capture and stays out until the lock has left the
// screen again.
//
// It is deliberately NOT the fullscreen auto-hide reveal that lives next to it in
// TopBar.qml. Outside fullscreen `FullscreenBarLogic._settle()` forces `revealed`
// true on every event it sees, so an arrival stored in that state would be undone
// by the next pointer move. The reverse must hold too: the arrival never
// collapses the bar in fullscreen, because that is the only job that state has.
// So the two are independent scalars that combine into one slide.

// Every input is clamped. An unclamped product lets a stray value above 1 push
// the offset past the viewport — which slides the bar clean off the far side and
// hides it again, the exact failure the clamp exists to prevent — and lets a
// negative invert the slide so a collapsed bar travels *inward*.
function clamp01(value) {
    const number = Number(value)
    if (!isFinite(number))
        return 0
    if (number < 0)
        return 0
    if (number > 1)
        return 1
    return number
}

// The single source of truth for how far the bar sits out of view: 0 collapsed,
// 1 at rest. A product rather than a minimum, an `or`, or an average, because
// each of those lets the mechanisms half-cancel into a bar parked in the middle
// of the screen. With a product, either one holding at 0 collapses it.
//
// `coverProgress` is the launcher's full-screen power cover taking the screen
// for itself: that surface owns every edge while it is up, so the bar leaves
// with the same slide it uses for a lock's stand-down rather than growing a
// second offset that could disagree with this one. Omitting it means "no cover".
function slideProgress(autoRevealProgress, arrivalProgress, coverProgress) {
    const cover = coverProgress === undefined ? 1 : clamp01(coverProgress)
    return clamp01(autoRevealProgress) * clamp01(arrivalProgress) * cover
}

// Whether the arrival may play. Two independent conditions, both required: this
// screen's widgets have staged, and nothing owns the screen that would slide
// unseen behind it — a session-start lock that has not left yet, or the
// stand-down an accepted lock request raises against the capture.
function shouldArrive(staged, arrivalAllowed) {
    return staged === true && arrivalAllowed === true
}

// Whether the bar claims its full input region. Once it has arrived the
// auto-hide machine owns that decision alone; while it is arriving, and once it
// is standing down for a lock, the bar keeps the same thin strip a collapsed bar
// claims, so an invisible bar cannot silently eat clicks along the screen edge.
// The same holds while a cover has taken the screen: a slid-out bar that still
// claimed its region would eat clicks meant for the cover above it.
function claimsFullRegion(revealed, arrivalClaimed, coverProgress) {
    const cover = coverProgress === undefined ? 1 : clamp01(coverProgress)
    return revealed === true && arrivalClaimed === true && cover >= 1
}
