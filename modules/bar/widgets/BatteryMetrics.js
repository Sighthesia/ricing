.pragma library

// Format a positive power rate without exposing noisy floating-point tails.
function formatRate(watts) {
    var value = Number(watts)
    if (!isFinite(value) || value <= 0)
        return "—"
    return (Math.round(value * 10) / 10).toFixed(1) + " W"
}

// Format UPower's seconds estimate as a compact human-readable duration.
function formatDuration(seconds) {
    var value = Number(seconds)
    if (!isFinite(value) || value <= 0)
        return "—"

    var totalMinutes = Math.max(1, Math.round(value / 60))
    if (totalMinutes < 60)
        return totalMinutes + " min"

    var hours = Math.floor(totalMinutes / 60)
    var minutes = totalMinutes % 60
    if (hours < 24)
        return hours + " h" + (minutes > 0 ? " " + minutes + " min" : "")

    var days = Math.floor(hours / 24)
    var remainingHours = hours % 24
    return days + " d" + (remainingHours > 0 ? " " + remainingHours + " h" : "")
}
