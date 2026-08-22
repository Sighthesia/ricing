.pragma library

// The wave owner serves the launcher; settings and music keep dedicated owners.
// Deprecated Wiki/News/Beatmap content targets are no longer routable.

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
