.pragma library

// Local solar calculation (NOAA simplified) for sunrise/sunset timetable.
// Reference: noctalia-shell derives sunrise/sunset from Open-Meteo daily
// data (https://github.com/noctalia-dev/noctalia-shell/blob/main/Services/Location/LocationService.qml)
// and passes lat/lon to wlsunset for auto scheduling. Afloat computes the
// same timetable offline from lat/lon so auto theme works without network;
// city names are resolved to coordinates first (see LocationService).
//
// All math is pure JS (no Date networking, no QML imports) so it stays
// runnable under plain qmltestrunner.

var ZENITH = 90.833 // official sunrise/sunset zenith (incl. refraction)
var MINUTES_PER_DAY = 1440

function _deg2rad(deg) {
    return deg * Math.PI / 180.0
}

function _rad2deg(rad) {
    return rad * 180.0 / Math.PI
}

// Latitude in [-90, 90]; longitude in [-180, 180]. String input tolerated;
// empty/blank input counts as invalid (no fix yet).
function isValidLatitude(value) {
    if (value == null || String(value).trim() === "")
        return false
    var v = Number(value)
    return isFinite(v) && v >= -90 && v <= 90
}

function isValidLongitude(value) {
    if (value == null || String(value).trim() === "")
        return false
    var v = Number(value)
    return isFinite(v) && v >= -180 && v <= 180
}

function parseLatitude(value) {
    if (value == null || String(value).trim() === "")
        return NaN
    var v = Number(String(value).trim())
    return isValidLatitude(v) ? v : NaN
}

function parseLongitude(value) {
    if (value == null || String(value).trim() === "")
        return NaN
    var v = Number(String(value).trim())
    return isValidLongitude(v) ? v : NaN
}

function minutesToHHMM(minutes) {
    var m = Math.floor(Number(minutes))
    if (!isFinite(m))
        return "00:00"
    m = ((m % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY
    var h = Math.floor(m / 60)
    var mm = m % 60
    return (h < 10 ? "0" + h : "" + h) + ":" + (mm < 10 ? "0" + mm : "" + mm)
}

function _dayOfYear(year, month, day) {
    // month: 1-12. Leap-year aware via UTC date math.
    var d = Date.UTC(year, month - 1, day)
    var start = Date.UTC(year, 0, 0)
    return Math.floor((d - start) / 86400000)
}

// Core NOAA iteration for one event (isSunrise true/false).
// Returns minutes since local midnight, or -1 when the sun never
// rises/sets on this date at this latitude (polar night/day).
function _calcEventMinutes(dayOfYear, latitude, longitude, tzOffsetMinutes, isSunrise) {
    var lngHour = longitude / 15.0
    var t = dayOfYear + (isSunrise ? (6 - lngHour) / 24.0 : (18 - lngHour) / 24.0)

    var m = 0.9856 * t - 3.289
    var l = m + 1.916 * Math.sin(_deg2rad(m)) + 0.020 * Math.sin(_deg2rad(2 * m)) + 282.634
    l = ((l % 360) + 360) % 360

    var ra = _rad2deg(Math.atan(0.91764 * Math.tan(_deg2rad(l))))
    ra = ((ra % 360) + 360) % 360
    var lQuadrant = Math.floor(l / 90) * 90
    var raQuadrant = Math.floor(ra / 90) * 90
    ra = ra + (lQuadrant - raQuadrant)
    ra /= 15.0

    var sinDec = 0.39782 * Math.sin(_deg2rad(l))
    var cosDec = Math.cos(Math.asin(sinDec))

    var cosH = (Math.cos(_deg2rad(ZENITH)) - sinDec * Math.sin(_deg2rad(latitude)))
            / (cosDec * Math.cos(_deg2rad(latitude)))
    if (cosH > 1)
        return -1 // polar night: sun never rises
    if (cosH < -1)
        return -1 // polar day: sun never sets (caller distinguishes via flag)

    var h = isSunrise
        ? 360 - _rad2deg(Math.acos(cosH))
        : _rad2deg(Math.acos(cosH))
    h /= 15.0

    var T = h + ra - 0.06571 * t - 6.622
    var ut = T - lngHour
    ut = ((ut % 24) + 24) % 24
    var local = ut * 60 + tzOffsetMinutes
    local = ((local % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY
    return Math.round(local)
}

// Date components + explicit tz offset (minutes east of UTC).
// Invalid inputs fall back to 06:30/18:30 so callers always get paintable times.
function calcSunTimes(year, month, day, latitude, longitude, tzOffsetMinutes) {
    var fallback = { sunriseMinutes: 390, sunsetMinutes: 1110,
        sunrise: "06:30", sunset: "18:30",
        polarDay: false, polarNight: false }
    var lat = Number(latitude)
    var lon = Number(longitude)
    var tz = Number(tzOffsetMinutes)
    if (!isFinite(lat) || !isFinite(lon) || !isFinite(tz))
        return fallback
    if (!isValidLatitude(lat) || !isValidLongitude(lon))
        return fallback
    var y = Math.floor(Number(year))
    var mo = Math.floor(Number(month))
    var d = Math.floor(Number(day))
    if (!isFinite(y) || !isFinite(mo) || !isFinite(d) || mo < 1 || mo > 12 || d < 1 || d > 31)
        return fallback

    var n = _dayOfYear(y, mo, d)
    var rise = _calcEventMinutes(n, lat, lon, tz, true)
    var set = _calcEventMinutes(n, lat, lon, tz, false)
    if (rise < 0 || set < 0) {
        // Distinguish polar day (sun always up -> full-day timetable)
        // from polar night (sun never up -> zero-day timetable).
        var lngHour = lon / 15.0
        var t = n + (12 - lngHour) / 24.0
        var m = 0.9856 * t - 3.289
        var l = m + 1.916 * Math.sin(_deg2rad(m)) + 0.020 * Math.sin(_deg2rad(2 * m)) + 282.634
        var sinDec = 0.39782 * Math.sin(_deg2rad(l))
        var cosDec = Math.cos(Math.asin(sinDec))
        var cosH = (Math.cos(_deg2rad(ZENITH)) - sinDec * Math.sin(_deg2rad(lat)))
                / (cosDec * Math.cos(_deg2rad(lat)))
        if (cosH < -1)
            return { sunriseMinutes: 0, sunsetMinutes: 1439,
                sunrise: "00:00", sunset: "23:59",
                polarDay: true, polarNight: false }
        return { sunriseMinutes: 0, sunsetMinutes: 0,
            sunrise: "00:00", sunset: "00:00",
            polarDay: false, polarNight: true }
    }
    return { sunriseMinutes: rise, sunsetMinutes: set,
        sunrise: minutesToHHMM(rise), sunset: minutesToHHMM(set),
        polarDay: false, polarNight: false }
}

// Convenience wrapper taking a local Date (uses its own tz offset).
function sunTimesForDate(date, latitude, longitude) {
    if (!date || typeof date.getFullYear !== "function")
        return calcSunTimes(2000, 1, 1, latitude, longitude, 0)
    return calcSunTimes(date.getFullYear(), date.getMonth() + 1, date.getDate(),
        latitude, longitude, -date.getTimezoneOffset())
}
