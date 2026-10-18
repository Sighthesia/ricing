.pragma library

// The wave owner serves the launcher; settings and music keep dedicated owners.
// The control center is not a coordinator target at all: it is a view inside the
// launcher page, reached from the launcher's rail, so it has no surface of its
// own to own. Deprecated Wiki/News/Beatmap content targets are no longer routable.

var targets = ["settings", "music", "launcher"]
var waveTargets = ["launcher"]

function normalizeTarget(target) {
    var candidate = target == null ? "" : String(target)
    return targets.indexOf(candidate) >= 0 ? candidate : ""
}

function ownerFor(target) {
    var normalized = normalizeTarget(target)
    if (waveTargets.indexOf(normalized) >= 0)
        return "wave"
    return normalized === "settings" || normalized === "music" ? normalized : ""
}

// The screen-scoped entry point asks this rather than hard-coding a branch per
// target: the answer is the wave owner's OWN method name, so the launcher
// cannot be reached by two different spellings of one owner.
//
// Empty for every other target, because those are dispatched by the coordinator
// itself and the wave owner has nothing to call - and now for "control-center"
// too, which is no longer a surface: it is a view inside the launcher page, so
// the screen scope has no method that opens it and must not pretend to one.
function entryMethodFor(target) {
    var normalized = normalizeTarget(target)
    if (waveTargets.indexOf(normalized) < 0)
        return ""
    return "requestOpen"
}

// What the screen-scoped entry point must do with a target, given the wave owner
// it has. Three answers, and the third is why this is asked here instead of
// inline:
//
//   "wave"        call `method` on the owner, which owns the session mirror, the
//                 opener record and the focus hand-off for its route
//   "coordinator" hand the target to the coordinator, which owns its own
//   "refuse"      the registry names a wave route the owner does not implement
//
// "refuse" is deliberately NOT a fallback to "coordinator". The coordinator would
// open the wave host with no session mirror, no requestedRoute and no opener, so
// the route would be on screen while every later decision - close, refocus, the
// next open intent - still believed it closed. A registry entry with no matching
// method is a drift bug between two lists that both look complete, so it is
// reported as one rather than dispatched as a working surface.
function dispatchFor(target, waveOwner) {
    var method = entryMethodFor(target)
    if (method === "")
        return { route: "coordinator", method: "" }
    if (!waveOwner || typeof waveOwner[method] !== "function")
        return { route: "refuse", method: method }
    return { route: "wave", method: method }
}
