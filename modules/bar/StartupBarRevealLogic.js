.pragma library

// The bar starts slid out of its own window viewport and slides in once its
// widgets are staged, so startup has an arrival instead of a pop-in.
//
// It is deliberately NOT the fullscreen auto-hide reveal that lives next to it in
// TopBar.qml. Outside fullscreen `FullscreenBarLogic._settle()` forces `revealed`
// true on every event it sees, so a startup expansion stored in that state would
// be undone by the next pointer event. The reverse must hold too: the startup
// expansion never collapses the bar in fullscreen, because that is the only job
// that state has. So the two are independent scalars that combine into one slide.

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
// each of those lets the two mechanisms half-cancel into a bar parked in the
// middle of the screen. With a product, either one holding at 0 collapses it.
function slideProgress(autoRevealProgress, startupProgress) {
    return clamp01(autoRevealProgress) * clamp01(startupProgress)
}

// The startup arrival is one-way. Only the auto-hide machine may take the bar
// back off screen, so nothing that happens after the slide can un-expand it —
// notably `BarContent.startupReady`, which drops back to false whenever staging
// re-enters, and the first pointer event after login.
function latchStartup(expanded, startupExpanded) {
    return expanded === true || startupExpanded === true
}

// Whether the startup arrival may start. Two independent conditions, both
// required: this screen's widgets have staged, and no session-start lock still
// owns the screen. Behind such a lock the slide plays unseen, and the desktop
// then comes up with the bar already at rest instead of arriving with it — so
// the expansion is deferred until the lock has left, not merely until staging
// finished.
function shouldExpandAtStartup(staged, startupRevealAllowed) {
    return staged === true && startupRevealAllowed === true
}

// Whether the bar claims its full input region. Once it has arrived the
// auto-hide machine owns that decision alone; while it is still arriving the bar
// keeps the same thin strip a collapsed bar claims, so an invisible startup bar
// cannot silently eat clicks along the screen edge.
function claimsFullRegion(revealed, startupExpanded) {
    return revealed === true && startupExpanded === true
}
