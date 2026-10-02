.pragma library

// Startup ladder shared by the root coordinator, the lock wave gate, and the
// per-screen chrome aggregation. Pure JS so the ordering can be asserted
// without mounting a shell, a window, or a service.

// Stages of one startup. They are integers so a caller can hold the current one
// and compare it, and the ladder only ever climbs.
var Stages = {
    // Lock surface and theme floor are up; nothing else exists yet.
    lockedFloor: 0,
    // The first wallpaper has been decoded and is revealing.
    wallpaperReveal: 1,
    // Chrome is mounted and its widget batches are still landing.
    chromeStaging: 2,
    // The lock wave has started, so background work may begin.
    quietReady: 3,
}

// The four events the ladder understands. Anything else is unknown and changes
// nothing.
var Events = {
    wallpaperReady: "wallpaper-ready",
    chromeMounted: "chrome-mounted",
    chromeReady: "chrome-ready",
    waveStarted: "wave-started",
}

// The whole contract, spelled out: one row per legal (stage, event) pair.
// `chrome-ready` is a row of its own and points back at chromeStaging, because
// chrome being fully built is a gate the caller records on its own boolean, not
// a stage of its own — quiet-ready is the wave itself.
var TRANSITIONS = [
    { from: Stages.lockedFloor, event: Events.wallpaperReady, to: Stages.wallpaperReveal },
    // Chrome may mount as soon as the settings-backed wallpaper request has
    // started. It stages alongside the wallpaper reveal; chrome-ready still
    // remains a separate gate for the startup lock wave.
    { from: Stages.lockedFloor, event: Events.chromeMounted, to: Stages.chromeStaging },
    { from: Stages.wallpaperReveal, event: Events.chromeMounted, to: Stages.chromeStaging },
    { from: Stages.chromeStaging, event: Events.chromeReady, to: Stages.chromeStaging },
    { from: Stages.chromeStaging, event: Events.waveStarted, to: Stages.quietReady },
]

// An unrecognized stage is read as the floor, so a caller that lost its state
// converges on the next real event instead of being stranded forever.
function normalizeStage(stage) {
    var value = Number(stage)
    if (value === Stages.lockedFloor || value === Stages.wallpaperReveal
            || value === Stages.chromeStaging || value === Stages.quietReady)
        return value
    return Stages.lockedFloor
}

// Stage reached by `event` at `stage`. A pair that is not in the table — an
// unknown event, or a known event arriving before its stage — returns the
// current stage unchanged, so a mis-wired caller cannot skip the ladder, and a
// duplicated signal can never walk it back down.
function advance(stage, event) {
    var current = normalizeStage(stage)
    for (var index = 0; index < TRANSITIONS.length; index++) {
        var step = TRANSITIONS[index]
        if (step.from !== current || step.event !== event)
            continue
        return step.to > current ? step.to : current
    }
    return current
}

// Whether a lock surface may start its entry wave. A request that does not
// claim to be a startup never consults the startup gates, so a configured
// manual reveal cannot be delayed by a boot that is still settling; anything
// that claims to be a startup waits for both gates. Only a gate that is
// literally true is open, so an undefined readiness holds the wave.
function waveAllowed(isStartup, wallpaperReady, chromeReady) {
    if (!isStartup)
        return true
    return wallpaperReady === true && chromeReady === true
}

// Screen names as a comparable list. A missing entry carries no identity to
// record, so it is dropped rather than counted as an unnamed screen.
function screenNames(list) {
    var source = list || []
    var result = []
    for (var index = 0; index < source.length; index++) {
        if (source[index] === null || source[index] === undefined)
            continue
        result.push(String(source[index]))
    }
    return result
}

// Whether every screen present right now has reported. An empty current list is
// never ready: with no screen there is nothing to have finished, and treating it
// as ready would open the startup wave on a shell with no output.
function allScreensReady(finishedNames, currentNames) {
    var current = screenNames(currentNames)
    if (!current.length)
        return false
    var finished = screenNames(finishedNames)
    for (var index = 0; index < current.length; index++) {
        if (finished.indexOf(current[index]) < 0)
            return false
    }
    return true
}

// Record one screen's completion. Duplicates are ignored and the caller's array
// is never mutated, so a screen that reports twice cannot make the other
// screens' work count twice or move an array a binding is watching.
function recordFinished(finishedNames, name) {
    var result = screenNames(finishedNames)
    var normalized = String(name === null || name === undefined ? "" : name)
    if (result.indexOf(normalized) < 0)
        result.push(normalized)
    return result
}
