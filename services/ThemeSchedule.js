.pragma library

function _degToRad(value) {
    return value * Math.PI / 180.0
}

function _radToDeg(value) {
    return value * 180.0 / Math.PI
}

function _normalizeDegrees(value) {
    var result = value % 360
    if (result < 0)
        result += 360

    return result
}

function _normalizeMinutes(value) {
    var result = value % 1440
    if (result < 0)
        result += 1440

    return result
}

function _dayOfYear(date) {
    var start = Date.UTC(date.getFullYear(), 0, 0)
    var current = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
    return Math.floor((current - start) / 86400000)
}

function _parseClockMinutes(value) {
    if (typeof value !== "string")
        return NaN

    var match = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(value.trim())
    if (!match)
        return NaN

    return parseInt(match[1], 10) * 60 + parseInt(match[2], 10)
}

function _clockDate(baseDate, minutes) {
    var normalized = _normalizeMinutes(minutes)
    return new Date(
        baseDate.getFullYear(),
        baseDate.getMonth(),
        baseDate.getDate(),
        Math.floor(normalized / 60),
        Math.floor(normalized % 60),
        0,
        0
    )
}

function _solarEvent(date, latitude, longitude, sunrise) {
    var zenith = 90.8333
    var day = _dayOfYear(date)
    var lngHour = longitude / 15.0
    var t = day + ((sunrise ? 6 : 18) - lngHour) / 24.0
    var meanAnomaly = 0.9856 * t - 3.289
    var trueLongitude = meanAnomaly
        + 1.916 * Math.sin(_degToRad(meanAnomaly))
        + 0.020 * Math.sin(2 * _degToRad(meanAnomaly))
        + 282.634
    trueLongitude = _normalizeDegrees(trueLongitude)

    var rightAscension = _radToDeg(Math.atan(0.91764 * Math.tan(_degToRad(trueLongitude))))
    rightAscension = _normalizeDegrees(rightAscension)

    var lQuadrant = Math.floor(trueLongitude / 90) * 90
    var raQuadrant = Math.floor(rightAscension / 90) * 90
    rightAscension += lQuadrant - raQuadrant
    rightAscension /= 15.0

    var sinDeclination = 0.39782 * Math.sin(_degToRad(trueLongitude))
    var cosDeclination = Math.cos(Math.asin(sinDeclination))
    var cosHourAngle = (
        Math.cos(_degToRad(zenith)) - sinDeclination * Math.sin(_degToRad(latitude))
    ) / (cosDeclination * Math.cos(_degToRad(latitude)))

    if (cosHourAngle < -1 || cosHourAngle > 1)
        return null

    var hourAngle = sunrise
        ? 360 - _radToDeg(Math.acos(cosHourAngle))
        : _radToDeg(Math.acos(cosHourAngle))
    hourAngle /= 15.0

    var localHour = hourAngle + rightAscension - 0.06571 * t - 6.622
    localHour -= lngHour
    localHour -= date.getTimezoneOffset() / 60.0

    return _clockDate(date, localHour * 60)
}

function _solarSchedule(date, latitude, longitude) {
    var sunriseToday = _solarEvent(date, latitude, longitude, true)
    var sunsetToday = _solarEvent(date, latitude, longitude, false)

    if (!sunriseToday || !sunsetToday)
        return { available: false, reason: "sunrise/sunset could not be calculated" }

    var targetDark
    var nextTransition

    if (date < sunriseToday) {
        targetDark = true
        nextTransition = sunriseToday
    } else if (date < sunsetToday) {
        targetDark = false
        nextTransition = sunsetToday
    } else {
        targetDark = true
        nextTransition = _solarEvent(new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1), latitude, longitude, true)
    }

    return {
        available: true,
        targetDark: targetDark,
        nextTransition: nextTransition,
        sunrise: sunriseToday,
        sunset: sunsetToday
    }
}

function _customSchedule(now, darkStartText, lightStartText) {
    var darkStart = _parseClockMinutes(darkStartText)
    var lightStart = _parseClockMinutes(lightStartText)

    if (isNaN(darkStart) || isNaN(lightStart))
        return { available: false, reason: "custom times must use HH:MM" }

    var nowMinutes = now.getHours() * 60 + now.getMinutes()

    if (darkStart === lightStart) {
        return {
            available: true,
            targetDark: true,
            nextTransition: null,
            darkStart: darkStartText,
            lightStart: lightStartText
        }
    }

    var targetDark
    var nextTransitionMinutes

    if (darkStart < lightStart) {
        targetDark = nowMinutes >= darkStart && nowMinutes < lightStart
        nextTransitionMinutes = targetDark ? lightStart : darkStart
    } else {
        targetDark = nowMinutes >= darkStart || nowMinutes < lightStart
        nextTransitionMinutes = targetDark
            ? (nowMinutes >= darkStart ? lightStart + 1440 : lightStart)
            : darkStart
    }

    var nextTransition = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0)
    nextTransition.setMinutes(nextTransitionMinutes)

    return {
        available: true,
        targetDark: targetDark,
        nextTransition: nextTransition,
        darkStart: darkStartText,
        lightStart: lightStartText
    }
}

function resolveDarkModeSchedule(appearance, now) {
    var mode = appearance.darkModeScheduleMode || "manual"
    var locationMode = appearance.darkModeScheduleLocationMode || "coordinates"

    if (locationMode === "city" && normalizeCityName(appearance.darkModeScheduleCity) === "")
        return { available: false, reason: "city name is required for city-based location mode" }

    if (mode === "sunrise-sunset") {
        var latitude = Number(appearance.darkModeScheduleLatitude)
        var longitude = Number(appearance.darkModeScheduleLongitude)

        if (!isFinite(latitude) || !isFinite(longitude))
            return { available: false, reason: "latitude and longitude must be numeric" }

        return _solarSchedule(now, latitude, longitude)
    }

    if (mode === "custom-time")
        return _customSchedule(now, appearance.darkModeScheduleDarkStart, appearance.darkModeScheduleLightStart)

    return {
        available: true,
        targetDark: !!appearance.darkMode,
        nextTransition: null,
        mode: "manual"
    }
}

function normalizeCityName(value) {
    if (typeof value !== "string")
        return ""

    return value.trim().replace(/\s+/g, " ")
}
