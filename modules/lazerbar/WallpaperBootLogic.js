.pragma library

function finite(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

function screenKey(name, x, y, width, height) {
    return String(name == null ? "" : name)
            + "@" + finite(x, 0) + "," + finite(y, 0)
            + "," + finite(width, 0) + "x" + finite(height, 0)
}

function currentKeys(screens) {
    var result = []
    for (var index = 0; index < (screens || []).length; index++) {
        var screen = screens[index]
        if (!screen)
            continue
        result.push(screenKey(screen.name, screen.x, screen.y,
                              screen.width, screen.height))
    }
    return result
}

function markFinished(finishedKeys, key) {
    var result = (finishedKeys || []).slice()
    var normalized = String(key == null ? "" : key)
    if (normalized && result.indexOf(normalized) < 0)
        result.push(normalized)
    return result
}

function isReady(finishedKeys, currentScreenKeys) {
    var finished = finishedKeys || []
    var current = currentScreenKeys || []
    if (!current.length)
        return false
    for (var index = 0; index < current.length; index++) {
        if (finished.indexOf(current[index]) < 0)
            return false
    }
    return true
}

// Which outcome the first wallpaper of a session resolves to, and therefore
// whether that screen still opens a circular reveal or settles directly. The
// order is the contract: an empty request stays an empty outcome even when the
// other flags are set, and a failed image is never treated as a reveal, so a
// boot path can report completion on any branch without inspecting a surface.
function bootOutcome(path, baseSource, imageFailed, reducedMotion) {
    if (!path)
        return "empty"
    if (imageFailed === true)
        return "error"
    if (reducedMotion === true)
        return "reduced-motion"
    if (path === String(baseSource))
        return "unchanged"
    return "reveal"
}
