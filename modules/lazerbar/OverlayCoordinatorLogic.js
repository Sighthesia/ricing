.pragma library

var targets = ["settings", "music", "wiki", "news", "beatmap"]
var waveTargets = ["wiki", "news", "beatmap"]

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

function isSameOwner(left, right) {
    var owner = ownerFor(left)
    return owner !== "" && owner === ownerFor(right)
}
