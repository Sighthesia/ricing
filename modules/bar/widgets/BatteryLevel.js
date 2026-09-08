.pragma library

// Battery level buckets shared by the bar widget and its tests so the
// icon on the bar cannot drift from the tested mapping.
function bucketFor(percentage) {
    var p = Number(percentage)
    if (!isFinite(p) || p < 0)
        return 0
    if (p < 12.5)
        return 0
    if (p < 37.5)
        return 25
    if (p < 62.5)
        return 50
    if (p < 87.5)
        return 75
    return 100
}

// Icon path (relative to modules/bar/widgets/) for a charge level.
// Unknown state renders the empty outline.
function iconFileFor(percentage, ready) {
    if (!ready)
        return "../icons/battery-0.svg"
    return "../icons/battery-" + bucketFor(percentage) + ".svg"
}
