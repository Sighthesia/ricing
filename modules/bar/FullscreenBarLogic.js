.pragma library

// Reveal state machine for the fullscreen auto-hide bar.
//
// The bar keeps its layer-shell surface and its exclusive zone while it is
// collapsed — niri sizes a fullscreen tile to the whole output, so the reserved
// strip is invisible while fullscreen and dropping the zone would only reflow
// the tiled windows twice per fullscreen toggle. Only the painted content
// leaves, and the surface's input region shrinks to a thin edge strip so the
// same surface (not a second, racing layer-shell surface) is the hover probe.
//
// The one rule that needs care is the arm flag. Collapsing under a pointer that
// is already sitting on the edge would immediately re-trigger on the reveal
// strip and flap the bar forever, so a reveal consumes the arm, and only a
// pointer that travels back out past the strip re-arms it.

// Painted edge hint, and the input region the collapsed bar keeps.
var revealStripHeight = 3

// A pointer counts as "away from the edge" once it is this far past the strip.
var revealArmSlack = 2

// Collapse again after this long without pointer movement.
//
// This is a SAFETY NET, not the normal path. Leaving the bar collapses it at
// once via a `leave` event, which sets the state directly without consulting
// this. So the delay only applies while the pointer is somewhere that never
// produces a leave — a surface that kept its hover, or a pointer that arrived
// before the bar was listening.
//
// It stays deliberately small: the whole point of the delay is to not delay.
var idleHideDelay = 200

// Smallest non-zero interval to hand a Timer. A Timer with interval 0 is
// not "immediate", it is a per-event-loop spin.
var minTimerInterval = 1

function initialState() {
    return {
        enabled: true,
        fullscreen: false,
        pinned: false,
        revealed: true,
        armed: true,
        hovered: false,
    }
}

function _copy(state) {
    return {
        enabled: !!state.enabled,
        fullscreen: !!state.fullscreen,
        pinned: !!state.pinned,
        revealed: !!state.revealed,
        armed: !!state.armed,
        hovered: !!state.hovered,
    }
}

// The bar is pinned open by anything that anchors to it: an open bar popup or a
// full-screen overlay would otherwise render against a bar that is off-screen.
function forcedVisible(state) {
    return !state.enabled || !state.fullscreen || state.pinned
}

function _settle(state) {
    if (forcedVisible(state)) {
        state.revealed = true
        state.armed = true
    }
    return state
}

// events: { type: "fullscreen" | "enabled" | "pinned" | "enter" | "leave" |
//           "move" | "hover" | "idle" | "reset", value, distance, slack }
function reduce(state, event) {
    var next = _copy(state || initialState())
    const type = event && event.type ? String(event.type) : ""

    if (type === "reset")
        return _settle(initialState())

    if (type === "fullscreen") {
        const fullscreen = event.value === true
        // No early return when the value is unchanged. Repeating an event has to
        // be idempotent in its RESULT, not skipped: a bar that only collapses on
        // a strict false->true edge is exactly the bar that collapses once and
        // then never again, because a previous collapse already left
        // `fullscreen` true with the bar hidden.
        next.fullscreen = fullscreen
        if (fullscreen) {
            // Collapse straight away, even under the pointer, and disarm so the
            // pointer resting on the new strip cannot re-trigger the reveal.
            next.revealed = false
            next.armed = false
        }
        return _settle(next)
    }

    if (type === "enabled") {
        next.enabled = event.value === true
        return _settle(next)
    }

    if (type === "pinned") {
        next.pinned = event.value === true
        if (next.pinned) {
            next.revealed = true
            next.armed = true
        }
        return _settle(next)
    }

    if (type === "enter") {
        next.hovered = true
        if (next.armed) {
            next.revealed = true
            next.armed = false
        }
        return _settle(next)
    }

    if (type === "leave") {
        next.hovered = false
        if (!forcedVisible(next))
            next.revealed = false
        next.armed = true
        return _settle(next)
    }

    if (type === "move") {
        const distance = Number(event.distance)
        if (!isFinite(distance))
            return _settle(next)
        const slack = event.slack == null ? revealArmSlack : Math.max(0, Number(event.slack))
        if (distance > revealStripHeight + (isFinite(slack) ? slack : revealArmSlack))
            next.armed = true
        return _settle(next)
    }

    // The pointer entered or left the bar without the caller distinguishing
    // which, so hover can be tracked without the caller reasoning about it.
    if (type === "hover") {
        next.hovered = event.value === true
        return _settle(next)
    }

    if (type === "idle") {
        // Ignore the idle collapse while the pointer is on the bar. Moving the
        // mouse restarts the caller's timer, so with a short delay the bar would
        // collapse a frame after every move and `leave` would reveal it again —
        // the bar would strobe under a stationary cursor. Hovering the bar is the
        // user looking at it, which is the one thing that must never hide it.
        if (next.hovered)
            return _settle(next)
        if (!forcedVisible(next)) {
            next.revealed = false
            next.armed = false
        }
        return _settle(next)
    }

    return _settle(next)
}

// Distance from the bar's anchored edge, for either position. `size` is the
// bar's own height so the bottom bar measures from its own bottom edge.
function distanceFromEdge(positionAlongBar, size, fromTop) {
    const value = Number(positionAlongBar)
    const extent = Number(size)
    if (!isFinite(value))
        return Infinity
    if (fromTop)
        return value
    return (isFinite(extent) ? extent : 0) - value
}

// Whether the edge strip can immediately summon a just-collapsed bar back,
// decided from the pointer's last known distance from the anchored edge.
// `pointerDistance` is negative (or non-finite) when the pointer was never seen
// over the bar.
//
// This must be a decision about the pointer's position, not a pointer-left
// event: collapsing shrinks the surface's input region under a resting pointer,
// and the compositor is not obliged to deliver a leave when it does. A bar left
// disarmed with no way to re-arm would stay off-screen for the rest of the
// fullscreen session. With an unknown position, arm anyway — a wrong reveal
// costs one edge hover, a missing arm costs the bar.
function rearmAfterCollapse(state, pointerDistance) {
    const distance = Number(pointerDistance)
    if (!isFinite(distance) || distance < 0)
        return reduce(state, { type: "leave" })
    return reduce(state, { type: "move", distance: distance })
}
