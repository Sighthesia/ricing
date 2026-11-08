// The bridge between the pure-JS marker state machine and `MotionTokens`.
//
// `SelectionMarkerMotion.js` is a `.pragma library` file: it is imported by a QML component
// and by node-driven probes alike, so it cannot import a QML singleton itself. The host
// calls `configure()` once with the values it read from `MotionTokens`, and the state
// machine asks this file for them.
//
// One place, so a duration cannot be a magic number in the state machine and a token in the
// component: the numbers live in `MotionTokens.qml` and are handed over.
.pragma library

var _focusDuration = 160
var _trailRate = 0.2

function configure(focusDuration, trailRate) {
    if (isFinite(focusDuration) && focusDuration > 0)
        _focusDuration = Number(focusDuration)
    if (isFinite(trailRate) && trailRate > 0 && trailRate <= 1)
        _trailRate = Number(trailRate)
}

function focusDuration() { return _focusDuration }
function trailRate() { return _trailRate }
