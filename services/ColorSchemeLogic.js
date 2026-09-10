.pragma library

// Pure scheduling math for automatic light/dark switching (cf. noctalia's
// DarkModeService): resolve the painted mode from the user's intent plus a
// sunrise/sunset timetable or the OS-reported color scheme. Stateless and
// UI-free so it stays runnable under plain qmltestrunner.

var DEFAULT_SUNRISE = "06:30"
var DEFAULT_SUNSET = "18:30"
var MINUTES_PER_DAY = 1440

// User intent: fixed "dark"/"light", or "auto" to follow a schedule.
function normalizeColorScheme(value) {
    var text = value == null ? "" : String(value).toLowerCase()
    return text === "dark" || text === "light" ? text : "auto"
}

// Auto-mode source: "time" follows the sunrise/sunset timetable,
// "system" follows the OS color scheme (falling back to time when unknown).
function normalizeAutoMode(value) {
    return value != null && String(value).toLowerCase() === "system" ? "system" : "time"
}

function normalizeSystemMode(value) {
    var text = value == null ? "" : String(value).toLowerCase()
    return text === "dark" ? "dark" : (text === "light" ? "light" : "unknown")
}

// "HH:MM" (single digits tolerated on either side) -> minutes since midnight, else -1.
function parseTimeMinutes(value) {
    if (value == null)
        return -1
    var match = String(value).trim().match(/^(\d{1,2}):(\d{1,2})$/)
    if (!match)
        return -1
    var hour = parseInt(match[1], 10)
    var minute = parseInt(match[2], 10)
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
        return -1
    return hour * 60 + minute
}

// Canonical "HH:MM"; garbage falls back to the stored value, then 00:00.
function normalizeTimeString(value, fallback) {
    var minutes = parseTimeMinutes(value)
    if (minutes < 0)
        minutes = parseTimeMinutes(fallback)
    if (minutes < 0)
        minutes = 0
    var hour = Math.floor(minutes / 60)
    var minute = minutes % 60
    return (hour < 10 ? "0" + hour : "" + hour) + ":" + (minute < 10 ? "0" + minute : "" + minute)
}

function _validOr(minutes, fallbackText) {
    var value = Number(minutes)
    if (isFinite(value) && value >= 0 && value < MINUTES_PER_DAY)
        return Math.floor(value)
    return parseTimeMinutes(fallbackText)
}

// Day is [sunrise, sunset); overnight ranges (sunrise after sunset) count
// the wrapped span as day so polar-style timetables still resolve.
function isDarkAtMinutes(nowMinutes, sunriseMinutes, sunsetMinutes) {
    var now = Number(nowMinutes)
    if (!isFinite(now))
        now = 0
    now = ((Math.floor(now) % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY
    var rise = _validOr(sunriseMinutes, DEFAULT_SUNRISE)
    var set = _validOr(sunsetMinutes, DEFAULT_SUNSET)
    var isDay
    if (rise <= set)
        isDay = now >= rise && now < set
    else
        isDay = now >= rise || now < set
    return !isDay
}

// The mode the shell should actually paint: "dark" or "light".
function effectiveMode(colorScheme, autoMode, sunrise, sunset, nowMinutes, systemMode) {
    if (normalizeColorScheme(colorScheme) !== "auto")
        return normalizeColorScheme(colorScheme)
    if (normalizeAutoMode(autoMode) === "system" && normalizeSystemMode(systemMode) !== "unknown")
        return normalizeSystemMode(systemMode)
    return isDarkAtMinutes(nowMinutes, parseTimeMinutes(sunrise), parseTimeMinutes(sunset)) ? "dark" : "light"
}
