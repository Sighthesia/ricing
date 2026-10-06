.pragma library

// The wave owner serves the launcher and its control-center sibling; settings
// and music keep dedicated owners. Deprecated Wiki/News/Beatmap content targets
// are no longer routable.

var targets = ["settings", "music", "launcher", "control-center"]
var waveTargets = ["launcher", "control-center"]

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
// route: the answer is the wave owner's OWN method name, so the launcher and the
// control center cannot be reached by two different spellings of one owner.
//
// Empty for every other target, because those are dispatched by the coordinator
// itself and the wave owner has nothing to call.
function entryMethodFor(target) {
    var normalized = normalizeTarget(target)
    if (waveTargets.indexOf(normalized) < 0)
        return ""
    return normalized === "control-center" ? "requestControlCenter" : "requestOpen"
}

// What the screen-scoped entry point must do with a target, given the wave owner
// it has. Three answers, and the third is why this is asked here instead of
// inline:
//
//   "wave"        call `method` on the owner, which owns the session mirror, the
//                 opener record and the focus hand-off for both of its routes
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
