// The one state machine that decides how a selection marker moves.
//
// REFERENCE: the mode split is taken from `modules/lazerbar/TrailIndicator.qml`, which
// already carries it for the workspace strip - a FIXED target is eased by two `Behavior`s,
// a target that is itself moving is pinned and followed. That split is right and it is the
// only thing this file ports. What it does NOT port is TrailIndicator's state: the failures
// in `BarWindowHintContent.qml` all came from several owners writing the same position, so
// this file is the single owner and the hosts only publish an anchor.
//
// Pure functions over a plain state object: no QML, no property bindings, so it can be
// reasoned about - and driven from a probe - without instantiating anything.
.pragma library
.import "MotionTokensBridge.js" as Tokens

// The four things a marker can be doing. Every event maps to exactly one, and the mapping
// is the whole design:
//
//   idle      the target is where the marker already is
//   focus     the MARK changed and the new row is standing still  -> travel, with a trail
//   follow    the marked row is being carried by the layout       -> track it, no restart
//   crossing  a workspace switch owns the path outright
var MODE_IDLE = "idle"
var MODE_FOCUS = "focus"
var MODE_FOLLOW = "follow"
var MODE_CROSSING = "crossing"

function createState() {
    return ({
        mode: MODE_IDLE,
        key: "",
        // The marker's position, and the only one anything draws from.
        position: 0,
        // Where it is heading. In `follow` this is re-read every frame; in `focus` it is
        // fixed for the length of the step.
        target: 0,
        // The trail's far end. Always lags `position`.
        tail: 0,
        // A `focus` step's own clock, in milliseconds elapsed.
        elapsed: 0,
        duration: 0,
        // The value the step started from, so a re-aim can restart from where it actually is.
        from: 0,
        // Which way the mark was last travelling: +1 down, -1 up, 0 at rest. The trail is
        // held on the far side of that, so it does not cross over when the motion reverses.
        tailDirection: 0,
        valid: false
    })
}

// THE EVENT THAT MATTERS. A marker is re-aimed by an anchor, and what it does next depends
// on two facts about that anchor and one about itself:
//
//   did the KEY change?        (the mark is pointing at a different window)
//   is the ROW moving?         (the layout is carrying it)
//
// Both were being inferred from indices and flags, one flag per combination, and each new
// flag broke a combination that had worked. They are the anchor's own two fields now.
//
// `now` is passed in rather than read, so a probe can step the clock deterministically.
function aim(state, anchor, reducedMotion) {
    if (!anchor || anchor.valid !== true) {
        state.valid = false
        state.mode = MODE_IDLE
        state.target = state.position
        return state
    }

    var keyChanged = String(anchor.key) !== String(state.key)
    var moving = anchor.moving === true
    state.key = String(anchor.key)
    state.valid = true

    if (moving) {
        // A ROW BEING CARRIED IS FOLLOWED, not eased to. Its position changes on every frame
        // by an amount the layout already chose; easing toward that is a second motion with
        // its own clock, and the two disagree for the length of the transition.
        state.mode = MODE_FOLLOW
        state.target = anchor.top
        // PLACED, on the event itself. `follow` means the row is being carried by the
        // layout, and its position on this frame is a fact, not a destination - deferring it
        // to the next tick puts the mark one frame behind the card for the whole transition,
        // which is a visible lag on a fast slide.
        state.position = anchor.top
        return state
    }

    if (keyChanged || state.mode === MODE_FOCUS) {
        // A MARK THAT CHANGED, ON A ROW THAT IS STILL. This is the one case that travels,
        // and it is what an ordinary focus step is.
        if (keyChanged) {
            state.from = state.position
            state.elapsed = 0
            state.duration = reducedMotion ? 0 : Tokens.focusDuration()
        }
        state.mode = MODE_FOCUS
        state.target = anchor.top
        return state
    }

    // Same mark, same row, not moving: nothing to do. A `follow` that has finished settles
    // here without a second motion.
    state.mode = MODE_IDLE
    state.target = anchor.top
    return state
}

// Advance one frame. `dt` is milliseconds since the previous step.
//
// Returns true when anything moved, which is what a host uses to decide whether it still
// needs to tick.
function step(state, dt, reducedMotion) {
    if (!state.valid)
        return false
    var before = state.position
    var beforeTail = state.tail

    if (state.mode === MODE_FOCUS) {
        state.elapsed = Math.min(state.duration, state.elapsed + dt)
        var p = state.duration > 0 ? state.elapsed / state.duration : 1
        state.position = state.from + (state.target - state.from) * easeOutQuad(p)
        if (state.elapsed >= state.duration)
            state.mode = MODE_IDLE
    } else if (state.mode === MODE_FOLLOW) {
        // Placed, not eased: the row is already where the layout put it on this frame.
        state.position = state.target
    } else if (state.mode === MODE_IDLE) {
        state.position = state.target
    }

    var moved = state.position - before
    if (Math.abs(moved) > 0.01)
        state.tailDirection = moved > 0 ? 1 : -1

    // THE TRAIL IS DERIVED, never a second position. It closes a fixed fraction of the gap
    // per frame, which is what keeps it moving: a `Behavior` handed a new target on every
    // frame restarts its easing from wherever it had got to and never leaves its start.
    //
    // It trails BEHIND, and `follow` is where that has to be said explicitly: the position
    // there is placed on the card, and a tail closing a fraction of the gap on the same
    // frame would end up on the far side of it as soon as the card turned around - measured,
    // a length of -6.7 on a card that had started sliding back. The tail is held to the side
    // the mark came from, which is what "behind" means once the motion reverses.
    // The tail closes a fraction of the gap and is then held to the side it came from: it
    // may lag, it may not cross. Without the second half it overshoots whenever the card
    // reverses - measured, a length of -14.5 on a card sliding back up.
    var rate = trailRate(reducedMotion)
    state.tail += (state.position - state.tail) * rate
    if (state.tailDirection > 0 && state.tail > state.position)
        state.tail = state.position
    if (state.tailDirection < 0 && state.tail < state.position)
        state.tail = state.position

    return Math.abs(state.position - before) > 0.001
        || Math.abs(state.tail - beforeTail) > 0.001
}

// Close the trail outright - used when the surface is hidden, so the next open starts
// settled instead of inheriting a wake from the last one.
function settle(state) {
    state.position = state.target
    state.tail = state.target
    state.mode = MODE_IDLE
    state.elapsed = state.duration
}

function easeOutQuad(t) {
    var x = Math.max(0, Math.min(1, t))
    return x * (2 - x)
}

function trailRate(reducedMotion) {
    return reducedMotion ? 1 : Tokens.trailRate()
}
