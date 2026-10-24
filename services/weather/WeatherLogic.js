.pragma library

// Pure weather contracts for WeatherService: Open-Meteo response
// normalization, cache state against one explicit TTL, and request-URL
// formation that refuses unusable coordinates.
//
// Reference: the free Open-Meteo current-weather endpoint
// https://api.open-meteo.com/v1/forecast?current=temperature_2m,weather_code
// (the same provider family noctalia-shell reads weather from — see
// services/LocationService.qml, which already uses Open-Meteo for sunrise and
// sunset). Weather interpretation codes are the WMO 4677 table Open-Meteo
// documents.
//
// Stateless and free of QML/Quickshell imports, matching the other
// services/*/*.js siblings, so it resolves entirely from its inputs: no
// service, no clock, and no network.

// How long a cached reading stays fresh. This is the single TTL: the service
// derives both its refresh cadence and its staleness threshold from it, so the
// header can never show a reading the refresh schedule would already have
// replaced. Weather observations are also reported in whole 15-minute
// intervals, so a much shorter window would buy nothing but requests.
var cacheTtlMs = 30 * 60 * 1000

// The Open-Meteo current-weather endpoint. Kept here so the request path is
// part of the tested contract rather than a string buried in the service.
var endpoint = "https://api.open-meteo.com/v1/forecast"

// Stable internal condition labels. The UI branches on these, never on a raw
// WMO code, so an unrecognized code degrades to "unknown" instead of painting
// nothing.
var unknownCondition = "unknown"

// WMO 4677 weather interpretation codes, folded onto the labels above:
// 0 clear, 1-2 mainly clear/partly cloudy, 3 overcast, 45/48 fog,
// 51-57 drizzle/freezing drizzle, 61-67 rain/freezing rain,
// 71-77 snow/snow grains, 80-82 rain showers, 85-86 snow showers,
// 95-99 thunderstorm with and without hail.
var conditionByCode = {
    0: "clear",
    1: "partly-cloudy",
    2: "partly-cloudy",
    3: "cloudy",
    45: "cloudy",
    48: "cloudy",
    51: "rain",
    53: "rain",
    55: "rain",
    56: "rain",
    57: "rain",
    61: "rain",
    63: "rain",
    65: "rain",
    66: "rain",
    67: "rain",
    71: "snow",
    73: "snow",
    75: "snow",
    77: "snow",
    80: "rain",
    81: "rain",
    82: "rain",
    85: "snow",
    86: "snow",
    95: "storm",
    96: "storm",
    99: "storm"
}

// The label for one WMO code, or "unknown". A non-numeric or absent code is
// not an error: the temperature alone still makes the reading usable.
function conditionForCode(code) {
    var key = toNumber(code, Number.NaN)
    if (!isFinite(key))
        return unknownCondition
    var label = conditionByCode[key]
    return typeof label === "string" ? label : unknownCondition
}

// Normalize a raw response body into the reading the header renders.
//
// `now` is the epoch millisecond stamp of the parse itself and defaults to the
// clock; tests pass it explicitly so `updatedAt` and the staleness check are
// deterministic. A response is usable when it carries a numeric current
// temperature, regardless of whether its code was recognized.
// `error` carries an i18n KEY, not a sentence: this module is shared by the
// service and its callers, and a baked-in language would pin the message to
// whatever locale the parser was written in. The service resolves it through
// Services.Tr before showing it.
function parseResponse(jsonText, now) {
    var payload = parseObject(jsonText)
    if (!payload)
        return { ok: false, error: "weather.parseFailed" }

    var current = payload.current
    if (current == null || typeof current !== "object")
        return { ok: false, error: "weather.noCurrent" }

    var temperature = toNumber(current.temperature_2m, Number.NaN)
    if (!isFinite(temperature))
        return { ok: false, error: "weather.noTemperature" }

    return {
        ok: true,
        temperature: temperature,
        condition: conditionForCode(current.weather_code),
        location: cityFromTimezone(payload.timezone),
        updatedAt: toNumber(now, Date.now())
    }
}

// The public state of the optional weather header, derived from one cache
// record. `loading` is the caller's own in-flight flag: the cache cannot answer
// it, and defaulting it to false keeps the two-argument form usable.
//
// A stale reading stays available on purpose. The header is optional and must
// never blank itself because a refresh failed or ran late, so the last known
// reading keeps rendering (marked stale) instead of dropping to unavailable.
function cacheState(cache, now, loading) {
    var record = cache != null && typeof cache === "object" ? cache : null
    var temperature = record ? toNumber(record.temperature, Number.NaN) : Number.NaN
    var updatedAt = record ? toNumber(record.updatedAt, 0) : 0
    var available = record !== null && isFinite(temperature)
    return {
        available: available,
        loading: loading === true,
        isStale: !available || isExpired(updatedAt, now),
        temperature: available ? temperature : Number.NaN,
        condition: labelFor(record ? record.condition : null),
        location: text(record ? record.location : null),
        updatedAt: updatedAt
    }
}

// A reading is fresh only while it has a usable timestamp younger than the TTL
// and not dated in the future — a clock change must not be able to keep a
// reading alive forever.
function isExpired(updatedAt, now) {
    var stamp = toNumber(updatedAt, 0)
    if (!isFinite(stamp) || stamp <= 0)
        return true
    var current = toNumber(now, Number.NaN)
    if (!isFinite(current))
        return true
    var age = current - stamp
    return age < 0 || age >= cacheTtlMs
}

// Whether a coordinate pair can form a request. This is the single source of
// truth for the check, so a caller cannot accept a pair that requestUrl() would
// then refuse. Blank input is a refusal, not the origin: Number("") is 0, and
// quietly resolving an empty field to latitude 0 would point the reading at the
// Gulf of Guinea instead of at nothing.
function hasCoordinates(latitude, longitude) {
    return isFinite(SolarCoord.parseLatitude(latitude))
        && isFinite(SolarCoord.parseLongitude(longitude))
}

// The current-weather request URL, or "" when the coordinates cannot form one.
// Empty is the caller's signal to skip the network entirely, which is what
// keeps refresh() from becoming a request that cannot succeed.
function requestUrl(latitude, longitude) {
    var lat = SolarCoord.parseLatitude(latitude)
    var lon = SolarCoord.parseLongitude(longitude)
    if (!isFinite(lat) || !isFinite(lon))
        return ""
    return endpoint + "?latitude=" + formatCoordinate(lat)
        + "&longitude=" + formatCoordinate(lon)
        + "&current=temperature_2m,weather_code"
        + "&temperature_unit=celsius"
        + "&wind_speed_unit=kmh"
        + "&timezone=auto"
}

// Open-Meteo accepts plain decimals; trim the float noise JS adds without
// losing the four-decimal precision LocationService persists.
function formatCoordinate(value) {
    return String(Math.round(value * 10000) / 10000)
}

// Open-Meteo answers with an IANA zone rather than a place name, so the city is
// the last segment ("Asia/Shanghai" -> "Shanghai"). A zone without a city
// segment yields no location rather than the raw zone string, which would read
// as noise next to a temperature.
function cityFromTimezone(value) {
    var zone = text(value)
    if (zone === "")
        return ""
    var segments = zone.split("/")
    var city = text(segments[segments.length - 1])
    // UTC and fixed offsets are zones, not places.
    if (city === "" || city === "UTC" || /^[+-]/.test(city))
        return ""
    return city
}

function labelFor(value) {
    var label = text(value)
    return label === "" ? unknownCondition : label
}

function parseObject(jsonText) {
    if (jsonText == null)
        return null
    var text = String(jsonText).trim()
    if (text === "")
        return null
    var parsed
    try {
        parsed = JSON.parse(text)
    } catch (err) {
        return null
    }
    return parsed != null && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : null
}

function text(value) {
    if (value == null)
        return ""
    return String(value).trim()
}

// Strict numeric coercion. Plain Number() maps null to 0, true to 1, and [] to
// 0, so an API payload carrying `"temperature_2m": null` would otherwise render
// as a perfectly plausible 0 degrees and a null weather code as clear sky —
// the two worst possible readings, both of them confident. Only a real number
// or a numeric string is a reading; anything else is absent.
function toNumber(value, fallback) {
    var isNumber = typeof value === "number"
    if (!isNumber && typeof value !== "string")
        return fallback
    if (!isNumber && String(value).trim() === "")
        return fallback
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

// Coordinate ranges, shared with the settings contract so a value
// SettingsService.locationCoordsValid rejects is one this module also refuses.
// Inlined rather than imported: SolarCalc.js is a sibling in services/, and a
// nested services/weather/ module importing "../SolarCalc.js" is a relative
// path that only Quickshell resolves, inside the config root.
var SolarCoord = {
    parseLatitude: function (value) {
        return parseCoordinate(value, 90)
    },
    parseLongitude: function (value) {
        return parseCoordinate(value, 180)
    }
}

function parseCoordinate(value, limit) {
    var number = toNumber(value, Number.NaN)
    if (!isFinite(number) || number < -limit || number > limit)
        return NaN
    return number
}