import QtQuick
import QtTest
import "../../services/weather/WeatherLogic.js" as Logic

// Verify the pure weather contracts: Open-Meteo response normalization into a
// stable internal condition label, cache state (available/stale) against an
// explicit TTL, and request-URL formation that refuses unusable coordinates.
//
// Everything here is deterministic through the `now` arguments, so no clock,
// network, or service is involved and the file stays headless.
Item {
    id: testRoot
    width: 800
    height: 600

    TestCase {
        name: "WeatherLogic"
        when: windowShown
        width: 800
        height: 600

        function test_validResponse() {
            var result = Logic.parseResponse(JSON.stringify({
                current: { temperature_2m: 18.5, weather_code: 1 },
                timezone: "Asia/Shanghai"
            }))
            verify(result.ok)
            compare(result.temperature, 18.5)
            compare(result.condition, "partly-cloudy")
        }

        function test_invalidResponseAndCacheStates() {
            verify(!Logic.parseResponse("{").ok)
            compare(Logic.cacheState(null, 1000).available, false)
            compare(Logic.cacheState({ temperature: 18, updatedAt: 0 }, 1000).isStale, true)
        }

        function test_conditionLabelMapping() {
            // Every WMO code Open-Meteo documents collapses onto one of the
            // stable internal labels, so the UI never branches on a raw number.
            var labels = ["clear", "partly-cloudy", "cloudy", "rain", "snow", "storm"]
            // A representative code for each family, checked by label so the
            // table can grow without the test enumerating all 28 codes.
            compare(Logic.conditionForCode(0), "clear")
            compare(Logic.conditionForCode(1), "partly-cloudy")
            compare(Logic.conditionForCode(2), "partly-cloudy")
            compare(Logic.conditionForCode(3), "cloudy")
            compare(Logic.conditionForCode(45), "cloudy")
            compare(Logic.conditionForCode(48), "cloudy")
            compare(Logic.conditionForCode(51), "rain")
            compare(Logic.conditionForCode(55), "rain")
            compare(Logic.conditionForCode(61), "rain")
            compare(Logic.conditionForCode(66), "rain")
            compare(Logic.conditionForCode(71), "snow")
            compare(Logic.conditionForCode(77), "snow")
            compare(Logic.conditionForCode(82), "rain")
            compare(Logic.conditionForCode(86), "snow")
            compare(Logic.conditionForCode(95), "storm")
            compare(Logic.conditionForCode(99), "storm")
            // A code outside the table is not an error: the temperature still
            // makes the reading usable, it just carries no icon.
            compare(Logic.conditionForCode(-1), "unknown")
            compare(Logic.conditionForCode(null), "unknown")
            compare(Logic.conditionForCode("nonsense"), "unknown")
            for (var i = 0; i <= 99; i++) {
                verify(labels.indexOf(Logic.conditionForCode(i)) >= 0
                    || Logic.conditionForCode(i) === "unknown",
                    "code " + i + " produced an out-of-vocabulary label")
            }
        }

        function test_responseFieldsAndLocation() {
            var payload = JSON.stringify({
                current: { temperature_2m: -3.5, weather_code: 71 },
                timezone: "Europe/Berlin"
            })
            var result = Logic.parseResponse(payload, 1000)
            verify(result.ok)
            compare(result.temperature, -3.5)
            compare(result.condition, "snow")
            compare(result.location, "Berlin")
            // The reading time is the moment the response was parsed, so a test
            // can pin it; the service relies on it for the staleness check.
            compare(result.updatedAt, 1000)
            // A numeric temperature is a valid reading even with no icon.
            var iconless = Logic.parseResponse(JSON.stringify({
                current: { temperature_2m: 0, weather_code: 999 }
            }), 2000)
            verify(iconless.ok)
            compare(iconless.temperature, 0)
            compare(iconless.condition, "unknown")
        }

        function test_responseFailuresAreExplicit() {
            var cases = [
                "{",
                "",
                "null",
                "[]",
                "42",
                "\"text\"",
                JSON.stringify({ current: {} }),
                JSON.stringify({ current: { temperature_2m: null } }),
                JSON.stringify({ current: { temperature_2m: "warm" } }),
                JSON.stringify({ current: { temperature_2m: NaN } }),
                JSON.stringify({ timezone: "Asia/Shanghai" })
            ]
            for (var i = 0; i < cases.length; i++) {
                var result = Logic.parseResponse(cases[i])
                verify(!result.ok, "payload " + i + " should not parse: " + cases[i])
                verify(typeof result.error === "string" && result.error.length > 0,
                    "payload " + i + " should report why: " + cases[i])
            }
            // A response that does not parse never reports a reading.
            var failed = Logic.parseResponse("{")
            verify(failed.temperature === undefined)
            verify(failed.condition === undefined)
            verify(failed.location === undefined)
        }

        function test_freshAndStaleCache() {
            // A reading younger than the TTL is usable and not stale.
            var fresh = Logic.cacheState({ temperature: 18, condition: "clear",
                location: "Shanghai", updatedAt: 1000 }, 1000 + Logic.cacheTtlMs - 1)
            verify(fresh.available)
            verify(!fresh.isStale)
            compare(fresh.temperature, 18)
            compare(fresh.condition, "clear")
            compare(fresh.location, "Shanghai")
            compare(fresh.updatedAt, 1000)

            // At the TTL boundary it is stale but still usable: the header keeps
            // the last reading rather than blanking.
            var stale = Logic.cacheState({ temperature: 18, condition: "clear",
                location: "Shanghai", updatedAt: 1000 }, 1000 + Logic.cacheTtlMs)
            verify(stale.available)
            verify(stale.isStale)
            compare(stale.temperature, 18)

            // A cache with no usable timestamp is always stale, whatever the
            // clock says.
            verify(Logic.cacheState({ temperature: 18, updatedAt: 0 }, 1000).isStale)
            verify(Logic.cacheState({ temperature: 18 }, 1000).isStale)
            verify(Logic.cacheState({ temperature: 18, updatedAt: Number.NaN }, 1000).isStale)
        }

        function test_noCache() {
            var empty = Logic.cacheState(null, 1000)
            verify(!empty.available)
            verify(empty.isStale)
            verify(!empty.loading)
            verify(isNaN(empty.temperature))
            compare(empty.condition, "unknown")
            compare(empty.location, "")
            compare(empty.updatedAt, 0)

            // Every absent shape is the same absent state, not a throw.
            for (var i = 0; i < 1; i++) {
                verify(!Logic.cacheState(undefined, 1000).available)
                verify(!Logic.cacheState(0, 1000).available)
                verify(!Logic.cacheState("", 1000).available)
                verify(!Logic.cacheState({}, 1000).available)
                verify(!Logic.cacheState({ temperature: "warm", updatedAt: 1000 }, 1000).available)
                verify(!Logic.cacheState({ temperature: null, updatedAt: 1000 }, 1000).available)
                // A stale-but-usable cache is still available: the header shows
                // the last known reading while the refresh is in flight.
                verify(Logic.cacheState({ temperature: 18, updatedAt: 1 }, 1e12).available)
            }
        }

        function test_cacheStateIsDefensive() {
            // A hostile cache must not throw and must not invent a reading.
            verify(!Logic.cacheState({ temperature: {}, updatedAt: 1000 }, 1000).available)
            verify(!Logic.cacheState({ temperature: [], updatedAt: 1000 }, 1000).available)
            verify(!Logic.cacheState({ temperature: true, updatedAt: 1000 }, 1000).available)
            // A numeric string survives a hand-edited cache file.
            var coerced = Logic.cacheState({ temperature: "18.5", updatedAt: "1000" }, 1000)
            verify(coerced.available)
            compare(coerced.temperature, 18.5)
            compare(coerced.updatedAt, 1000)
            // A nonsense clock reads as stale rather than fresh.
            verify(Logic.cacheState({ temperature: 18, updatedAt: 1000 }, Number.NaN).isStale)
            verify(Logic.cacheState({ temperature: 18, updatedAt: 1000 }, -1).isStale)
            // A future timestamp (clock change) is stale too: it cannot be used
            // to keep a reading alive indefinitely.
            verify(Logic.cacheState({ temperature: 18, updatedAt: 1e12 }, 1000).isStale)
            // A cache carrying an unknown label is still a usable reading.
            var unknown = Logic.cacheState({ temperature: 18, condition: "hail",
                updatedAt: 1000 }, 1000)
            verify(unknown.available)
            compare(unknown.condition, "hail")
        }

        function test_cacheStateReportsLoadingFromCaller() {
            // `loading` is the service's own in-flight flag, not something the
            // cache can answer, so it is passed in and defaults to false.
            verify(!Logic.cacheState(null, 1000).loading)
            verify(Logic.cacheState(null, 1000, true).loading)
            // An in-flight refresh over a fresh reading keeps that reading.
            var inFlight = Logic.cacheState({ temperature: 18, updatedAt: 1000 }, 1000, true)
            verify(inFlight.available)
            verify(inFlight.loading)
            verify(!inFlight.isStale)
            // Only an explicit true means loading.
            verify(!Logic.cacheState(null, 1000, false).loading)
            verify(!Logic.cacheState(null, 1000, "yes").loading)
            verify(!Logic.cacheState(null, 1000, 1).loading)
        }

        function test_hasCoordinatesMatchesRequestUrl() {
            // The validity check and the URL builder must agree, or a caller
            // accepts a pair requestUrl() then refuses to build.
            var cases = [["", ""], [null, null], [undefined, undefined], ["  ", "  "],
                ["31.2", ""], ["", "121.5"], ["north", "east"], [Number.NaN, Number.NaN],
                [91, 0], [-91, 0], [0, 181], [0, -181], [1e9, 1e9], [[], []], [true, false],
                [{}, {}], [31.2304, 121.4737], ["31.2304", "121.4737"], [0, 0],
                [90, 180], [-90, -180]]
            for (var i = 0; i < cases.length; i++) {
                compare(Logic.hasCoordinates(cases[i][0], cases[i][1]),
                        Logic.requestUrl(cases[i][0], cases[i][1]) !== "",
                        "case " + i + " disagreed with requestUrl")
            }
            // Blank input is a refusal, not the origin: Number("") is 0, so a
            // lenient parse would point the reading at the Gulf of Guinea.
            verify(!Logic.hasCoordinates("", ""))
            verify(!Logic.hasCoordinates("0", ""))
            verify(!Logic.hasCoordinates("", "0"))
            verify(Logic.hasCoordinates(0, 0))
            // The limits themselves are inclusive, matching SolarCalc.
            verify(Logic.hasCoordinates(90, 180))
            verify(Logic.hasCoordinates(-90, -180))
            verify(!Logic.hasCoordinates(90.1, 0))
            verify(!Logic.hasCoordinates(0, -180.1))
        }

        function test_requestUrlRefusesUnusableCoordinates() {
            // No coordinates means no request at all: refresh() must be able to
            // return without touching the network.
            compare(Logic.requestUrl("", ""), "")
            compare(Logic.requestUrl(null, null), "")
            compare(Logic.requestUrl(undefined, undefined), "")
            compare(Logic.requestUrl("  ", "  "), "")
            compare(Logic.requestUrl("31.2", ""), "")
            compare(Logic.requestUrl("", "121.5"), "")
            // Out-of-range values never produce a request either.
            compare(Logic.requestUrl(91, 0), "")
            compare(Logic.requestUrl(-91, 0), "")
            compare(Logic.requestUrl(0, 181), "")
            compare(Logic.requestUrl(0, -181), "")
            compare(Logic.requestUrl("north", "east"), "")
            compare(Logic.requestUrl(Number.NaN, Number.NaN), "")
            compare(Logic.requestUrl(1e9, 1e9), "")
        }

        function test_requestUrlForm() {
            var url = Logic.requestUrl(31.2304, 121.4737)
            verify(url.length > 0)
            verify(url.indexOf("https://api.open-meteo.com/v1/forecast") === 0)
            verify(url.indexOf("latitude=31.2304") > 0)
            verify(url.indexOf("longitude=121.4737") > 0)
            // The current-weather block the parser reads must be requested, and
            // the response must stay in the unit the parser expects.
            verify(url.indexOf("current=") > 0)
            verify(url.indexOf("temperature_2m") > 0)
            verify(url.indexOf("weather_code") > 0)
            verify(url.indexOf("temperature_unit=celsius") > 0)
            verify(url.indexOf("wind_speed_unit=") > 0 || url.indexOf("timezone=") > 0)
            // String coordinates from settings are accepted like numbers.
            compare(Logic.requestUrl("31.2304", "121.4737"), url)
            compare(Logic.requestUrl(" 31.2304 ", " 121.4737 "), url)
            // The whole-precision value must not be truncated to zero degrees.
            var equator = Logic.requestUrl(0, 0)
            verify(equator.indexOf("latitude=0") > 0)
            verify(equator.indexOf("longitude=0") > 0)
        }
    }
}