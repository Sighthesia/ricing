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
