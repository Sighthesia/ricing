import QtQuick
import Quickshell
import Quickshell.Io
import "./services" as Services
import "./services/weather/WeatherLogic.js" as WeatherLogic
import "./services/weather/WeatherSeams.js" as WeatherSeams
import "./modules/lazerbar/ControlCenterLogic.js" as ControlCenterLogic

// Load the real WeatherService singleton and check its public contract with no
// network, no dependence on the clock, and nothing written under the shell cache
// directory.
//
// This exists because a tests/qml/ QtTest file structurally cannot cover it: the
// Quickshell plugin is linked into the `qs` binary, so any file touching
// Quickshell.* fails to load under a bare qmltestrunner, and a file importing
// services/ from tests/qml/ has that import blackholed. The pure parsing and
// cache-state rules are covered by tests/qml/tst_weather_logic.qml; what only a
// real load can catch is that the singleton file binds, registers, adopts a
// persisted reading, and reports one coherent set of values.
//
// Determinism. The harness shares a process with the singleton, so it takes over
// both of the service's outbound edges through weather/WeatherSeams.js before its
// first reference to it:
//   * WeatherSeams.cachePathOverride points the persisted reading at a throwaway
//     file under /tmp/opencode. The run therefore neither reads the desktop's
//     real weather cache — which would make every assertion depend on what the
//     user last fetched — nor writes one.
//   * WeatherSeams.transport answers refresh() in-process, so every request the
//     service makes is recorded here and answered from a script. No socket is
//     ever opened, including for the refreshes the service starts on its own
//     (the construction timer and the coordinate-change timer). The transport
//     still ends in the service's own _applyResponse(), so this exercises the
//     production response path rather than a copy of it.
// Both are inert in production.
//
// FileView reads land on a worker thread, so the persisted reading is adopted a
// few milliseconds after construction. Every step that depends on one waits for
// it on a real timer and fails on a deadline rather than assuming a turn count —
// see waitFor().
Item {
    id: root

    // A throwaway cache file, seeded by this harness before the singleton is first
    // touched. Fixed name, overwritten by every run, so a file left by an earlier
    // run cannot leak into this one's assertions.
    readonly property string cachePath: "/tmp/opencode/afloat-weather-test-cache.json"
    // The stamp the fixture carries: a realistic epoch-millisecond value (~1.76e12,
    // past a 32-bit int's range, so it is also what catches a truncated updatedAt),
    // aged past the TTL because that is what a cache file written by an earlier
    // shell run actually looks like. Relative to the clock so the file is stale on
    // any machine, whatever its date.
    readonly property double fixtureStamp: Date.now() - 2 * WeatherLogic.cacheTtlMs
    // Coordinates used only by the response phase, distinct from the ones the
    // coordinate phase checks so the two cannot be confused.
    readonly property real scriptedLatitude: 12.5
    readonly property real scriptedLongitude: 34.5
    readonly property string scriptedUrl: WeatherLogic.requestUrl(12.5, 34.5)

    property int checks: 0
    property int failures: 0

    // Every URL the service asked for, and the answers it got. Until the response
    // phase the fallback answer re-adopts the fixture reading, so a refresh the
    // service starts by itself is idempotent instead of moving the state an
    // assertion is about to read. Afterwards the fallback is a failing status,
    // which reports itself but leaves the reading alone — the safe default for a
    // request nobody is asserting on.
    property string answerMode: "idempotent"
    property var answers: []
    property var requestedUrls: []

    // Harness-owned writer, used only to seed the file before construction.
    FileView {
        id: fixtureWriter
        path: root.cachePath
        blockLoading: true
        watchChanges: false
    }

    // --- assertions -------------------------------------------------------
    function check(label, actual, expected) {
        root.checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root.failures += 1
        console.log("FAIL:", label, "expected", expected, "got", actual)
    }

    // --- scripted transport ------------------------------------------------
    // The persisted reading, as a response body. Re-adopting it changes nothing,
    // which is what makes an unasserted refresh safe.
    function fixtureAnswer() {
        return { status: 200, now: root.fixtureStamp, body: JSON.stringify({
            current: { temperature_2m: 18.5, weather_code: 0 },
            timezone: "Asia/Shanghai"
        }) }
    }

    // Installed as WeatherSeams.transport: records the URL, then answers from the
    // script. Nothing here touches a socket.
    function transport(url) {
        root.requestedUrls.push(url)
        if (root.answers.length > 0)
            return root.answers.shift()
        return root.answerMode === "idempotent"
            ? root.fixtureAnswer()
            : { status: 0, body: "" }
    }

    function requestsFor(expectedUrl) {
        var count = 0
        for (var i = 0; i < root.requestedUrls.length; i++) {
            if (root.requestedUrls[i] === expectedUrl)
                count += 1
        }
        return count
    }

    // Every request the service made must be one requestUrl() could have built.
    function everyRequestIsWellFormed() {
        for (var i = 0; i < root.requestedUrls.length; i++) {
            var url = root.requestedUrls[i]
            if (url.indexOf(WeatherLogic.endpoint + "?latitude=") !== 0
                    || url.indexOf("&longitude=") < 0
                    || url.indexOf("&current=temperature_2m,weather_code") < 0)
                return false
        }
        return true
    }

    // The header's own view of the service, so the two contracts are checked
    // against each other rather than against this file's idea of either.
    function headerState(weather) {
        return ControlCenterLogic.weatherState({
            available: weather.available,
            temperature: weather.temperature,
            isStale: weather.isStale,
            loading: weather.loading,
            lastError: weather.lastError
        })
    }

    // --- waiting -----------------------------------------------------------
    // One Timer, with the wait kept as data so successive waits cannot stack up
    // duplicate handlers. A FileView read is a worker-thread round trip, so this
    // polls on real time and fails on a deadline instead of counting turns.
    function waitFor(label, predicate, continuation) {
        root.waitLabel = label
        root.waitPredicate = predicate
        root.waitContinuation = continuation
        root.waitedMs = 0
        waitTimer.running = false
        waitTimer.start()
    }

    property string waitLabel: ""
    property var waitPredicate: null
    property var waitContinuation: null
    property int waitedMs: 0

    property Timer waitTimer: Timer {
        interval: 5
        repeat: true
        onTriggered: {
            root.waitedMs += waitTimer.interval
            var satisfied = false
            try {
                satisfied = root.waitPredicate !== null && root.waitPredicate() === true
            } catch (err) {
                satisfied = false
            }
            if (!satisfied && root.waitedMs < 3000)
                return
            waitTimer.running = false
            var continuation = root.waitContinuation
            root.waitContinuation = null
            if (satisfied) {
                console.log("PASS: " + root.waitLabel + " (waited", root.waitedMs + "ms)")
            } else {
                // A wait that ran out is a failure, not a skip: continuing lets the
                // following assertions report what the service actually holds.
                root.check(root.waitLabel + " (waited " + root.waitedMs + "ms)", false, true)
            }
            if (continuation !== null)
                continuation()
        }
    }

    // --- phases ------------------------------------------------------------
    Component.onCompleted: {
        // Both seams go in before the singleton is first touched: it is
        // constructed on first use and cachePath reads the override at that
        // moment. Nothing above this line may reference Services.WeatherService.
        WeatherSeams.cachePathOverride = root.cachePath
        WeatherSeams.transport = root.transport

        // Seed the persisted reading the service is about to construct against.
        fixtureWriter.setText(JSON.stringify({
            temperature: 18.5,
            condition: "clear",
            location: "Shanghai",
            updatedAt: root.fixtureStamp
        }))

        root.waitFor("the fixture reached the disk", function() {
            return fixtureWriter.text().indexOf("18.5") >= 0
        }, root.adoptionPhase)
    }

    // The cache adoption path: a persisted record must become a live reading.
    function adoptionPhase() {
        // Referencing the singleton is itself part of the assertion. A QML error
        // here (unknown property, broken binding, missing import) fails to load and
        // this file never reports at all.
        var weather = Services.WeatherService

        root.waitFor("the persisted reading is adopted", function() {
            return weather.available === true
        }, function() {
            root.check("the cache was redirected off the shell cache directory",
                weather.cachePath, root.cachePath)
            root.check("the shell cache directory is not the one in use",
                weather.cachePath.indexOf(Quickshell.cacheDir), -1)
            root.check("an adopted reading is available", weather.available, true)
            root.check("an adopted reading has a temperature", weather.temperature, 18.5)
            root.check("an adopted reading has its condition", weather.condition, "clear")
            root.check("an adopted reading has its location", weather.location, "Shanghai")
            root.check("an adopted reading is not loading", weather.loading, false)
            root.check("an adopted reading starts without an error", weather.lastError, "")
            // The fixture is aged past the TTL, which is what a cache file from an
            // earlier run looks like. It must still be shown, marked stale — an
            // optional header degrades, it does not blank.
            root.check("an old adopted reading is stale", weather.isStale, true)
            root.check("an old adopted reading is still available", weather.available, true)
            root.check("an old adopted reading reads as stale, not unavailable",
                root.headerState(weather), "stale")

            // --- updatedAt must survive as epoch milliseconds ---
            // Declared int, a 1.76e12 stamp wrapped into a 32-bit value, so the
            // header would show a garbage age and the staleness check would be
            // reading nonsense. Exact equality is the assertion.
            root.check("updatedAt keeps epoch-millisecond precision",
                weather.updatedAt, root.fixtureStamp)
            root.check("updatedAt is neither wrapped nor scaled down",
                weather.updatedAt > 1600000000000, true)
            root.check("updatedAt is a whole number of milliseconds",
                Math.floor(weather.updatedAt) === weather.updatedAt, true)

            root.coordinatePhase()
        })
    }

    // Coordinate validation: a refused pair is never kept, and an accepted pair is
    // exactly what gets asked for.
    function coordinatePhase() {
        var weather = Services.WeatherService

        // Blank input is a refusal, not latitude 0: Number("") is 0, so a lenient
        // parse would aim the reading at the Gulf of Guinea.
        var refused = [["north", "east"], [91, 0], [0, 181], ["", ""], [0, -181],
            [Number.NaN, Number.NaN]]
        for (var i = 0; i < refused.length; i++) {
            root.check("refused pair " + i + " is refused",
                weather.setCoordinates(refused[i][0], refused[i][1]), false)
        }
        // Whatever the service falls back to after all of those, it is never half-set:
        // either nothing is ready and no finite position is pinned, or what is
        // ready is a pair requestUrl() would also accept.
        root.check("a refused pair leaves nothing half-set",
            weather.coordinatesReady
                ? WeatherLogic.hasCoordinates(weather.latitude, weather.longitude)
                : !isFinite(weather.latitude), true)

        // An accepted pair is kept, and the URL the service builds from it is the
        // one the pure module builds — the two cannot disagree.
        root.check("a valid pair is accepted", weather.setCoordinates(31.2304, 121.4737), true)
        root.check("the accepted latitude is kept", weather.latitude, 31.2304)
        root.check("the accepted longitude is kept", weather.longitude, 121.4737)
        root.check("an accepted pair is ready", weather.coordinatesReady, true)
        root.check("the accepted pair forms the expected request",
            WeatherLogic.requestUrl(weather.latitude, weather.longitude),
            WeatherLogic.requestUrl(31.2304, 121.4737))
        // A string pair from the settings form takes the same path.
        root.check("a string pair is accepted", weather.setCoordinates(" -33.87 ", "151.21"), true)
        root.check("the string latitude is stored", weather.latitude, -33.87)
        root.check("the string longitude is stored", weather.longitude, 151.21)
        root.check("the string pair forms a request",
            WeatherLogic.requestUrl(weather.latitude, weather.longitude) !== "", true)

        // A coordinate change asks for a reading one turn later, so the request the
        // service makes on its own is observable here — through the transport, never
        // over a socket.
        root.waitFor("the coordinate change asks for a reading", function() {
            return root.requestsFor(WeatherLogic.requestUrl(-33.87, 151.21)) >= 1
        }, function() {
            root.check("every request the service made was well formed",
                root.everyRequestIsWellFormed(), true)

            // An in-flight refresh is never doubled.
            weather.loading = true
            root.check("refresh returns while loading", weather.refresh(), false)
            root.check("an in-flight refresh reads as loading", weather.loading, true)
            // The header keeps the CACHED reading through the request rather than
            // reporting "loading": the whole point of a cache-first adapter is that
            // the number it already has survives the request that will replace it.
            // This is the same fixture as the adopt phase - aged past the TTL - so
            // the state is stale, which is exactly what a stale cache looks like
            // mid-refresh.
            root.check("a refresh in flight keeps the cached reading",
                root.headerState(weather), "stale")
            root.check("...and the cached temperature is still there",
                weather.temperature, 18.5)
            // With nothing cached the same flag does read as loading, so this is a
            // statement about the cache rather than about the flag.
            root.check("a loading header with no cache is loading",
                ControlCenterLogic.weatherState({ available: true, loading: true }),
                "loading")
            weather.loading = false

            // Clearing hands control back to the saved coordinates, whatever those
            // are on this machine.
            weather.clearCoordinates()
            root.check("clearing drops the override", weather.coordinatesReady,
                Services.SettingsService.locationCoordsValid)

            root.responsePhase()
        })
    }

    // The response path, driven through the transport: a success, a failed
    // request, an old reading, and an unusable body.
    function responsePhase() {
        var weather = Services.WeatherService
        weather.clearError()

        // Coordinates this phase owns. Installed once, so no later timer restarts
        // and no unasserted refresh can consume a scripted answer.
        weather.setCoordinates(root.scriptedLatitude, root.scriptedLongitude)
        root.waitFor("the scripted position is ready", function() {
            return root.requestsFor(root.scriptedUrl) >= 1
        }, function() {
            // From here on a request nobody is asserting on fails instead of
            // rewriting the reading.
            root.answerMode = "failing"

            // A success adopts the response and clears any earlier failure. The
            // answer pins the stamp, so the assertion is an exact equality against
            // a realistic epoch-ms value rather than a tolerance.
            var freshStamp = Date.now()
            root.answers = [{ status: 200, now: freshStamp, body: JSON.stringify({
                current: { temperature_2m: 21.5, weather_code: 3 },
                timezone: "Europe/Berlin"
            }) }]
            root.check("a refresh with usable coordinates starts", weather.refresh(), true)
            root.check("a success is not loading", weather.loading, false)
            root.check("a success clears the error", weather.lastError, "")
            root.check("a success adopts its temperature", weather.temperature, 21.5)
            root.check("a success adopts its condition", weather.condition, "cloudy")
            root.check("a success adopts its location", weather.location, "Berlin")
            root.check("a success stamps updatedAt exactly", weather.updatedAt, freshStamp)
            root.check("a fresh success is not stale", weather.isStale, false)
            root.check("a success reads as ready", root.headerState(weather), "ready")

            // A failed request reports itself and keeps the reading it happened on:
            // the header degrades to stale, it does not blank.
            root.answers = [{ status: 503, body: "" }]
            root.check("a failing refresh still counts as a request", weather.refresh(), true)
            root.check("a failure reports an error", weather.lastError !== "", true)
            root.check("a failure keeps the temperature", weather.temperature, 21.5)
            root.check("a failure keeps the reading available", weather.available, true)
            root.check("a failure reads as stale, not unavailable",
                root.headerState(weather), "stale")

            // An old response is adopted but retires as stale: still shown, marked.
            weather.clearError()
            root.answers = [{ status: 200, now: Date.now() - 2 * WeatherLogic.cacheTtlMs,
                body: JSON.stringify({
                    current: { temperature_2m: -3.5, weather_code: 71 }
                }) }]
            root.check("an old reading is still adopted", weather.refresh(), true)
            root.check("an old reading keeps its temperature", weather.temperature, -3.5)
            root.check("an old reading keeps its condition", weather.condition, "snow")
            root.check("an old reading is available", weather.available, true)
            root.check("an old reading is stale", weather.isStale, true)
            root.check("an old reading still carries an epoch-millisecond stamp",
                weather.updatedAt > 1600000000000, true)
            root.check("an old reading reads as stale", root.headerState(weather), "stale")

            // An unusable body is refused and the previous reading survives.
            root.answers = [{ status: 200, now: 1758300000999, body: "{not json" }]
            root.check("a malformed body is refused, not adopted", weather.refresh(), true)
            root.check("a malformed body reports an error", weather.lastError !== "", true)
            root.check("a malformed body keeps the reading", weather.temperature, -3.5)
            root.check("a malformed body keeps the reading available", weather.available, true)
            root.check("a malformed body keeps the stamp", weather.isStale, true)

            root.persistPhase()
        })
    }

    // Persist round trip: what the service wrote must be the whole record, stamp
    // included, at the redirected path.
    function persistPhase() {
        var weather = Services.WeatherService
        // A reader created after the write, with its path fixed at construction:
        // a FileView keeps the body it loaded and does not re-read a path assigned
        // later, so this has to be a new view rather than a second read of the old
        // one.
        var reader = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Item {'
            + 'id: persistReader; property bool ready: false; property string body: "";'
            + 'FileView { id: view; path: "' + root.cachePath + '";'
            + 'blockLoading: true; watchChanges: false;'
            + 'onLoaded: { persistReader.ready = true; persistReader.body = view.text() } } }',
            root, "persistReader")
        root.check("a reader on the redirected path was created", reader !== null, true)

        root.waitFor("the reading reached the cache file", function() {
            return reader !== null && reader.ready === true
        }, function() {
            var record = null
            try {
                record = reader.body ? JSON.parse(reader.body) : null
            } catch (err) {
                record = null
            }
            root.check("the persisted record is readable JSON", record !== null, true)
            if (record !== null) {
                root.check("the persisted record keeps the temperature",
                    record.temperature, -3.5)
                root.check("the persisted record keeps the condition",
                    record.condition, "snow")
                // The file is the round trip through JSON, so this is where a stamp
                // lost to a narrower type on the way out would show.
                root.check("the persisted record keeps epoch-millisecond precision",
                    record.updatedAt, weather.updatedAt)
                root.check("the persisted stamp is neither wrapped nor scaled",
                    record.updatedAt > 1600000000000, true)
            }
            root.check("the service is idle at the end", weather.loading, false)
            console.log("Totals:", root.checks - root.failures, "passed,",
                root.failures, "failed")
            Qt.quit()
        })
    }
}