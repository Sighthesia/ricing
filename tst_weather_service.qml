import QtQuick
import "./services" as Services
import "./services/weather/WeatherLogic.js" as WeatherLogic
import "./modules/lazerbar/ControlCenterLogic.js" as ControlCenterLogic

// Load the optional WeatherService singleton and check its public contract
// without opening a window or issuing a request.
//
// This exists because a tests/qml/ QtTest file structurally cannot cover it:
// the Quickshell plugin is linked into the `qs` binary, so any file touching
// Quickshell.* fails to load under a bare qmltestrunner, and a file importing
// services/ from tests/qml/ has that import blackholed. The pure parsing and
// cache-state rules are covered by tests/qml/tst_weather_logic.qml; what only a
// real load can catch is that the singleton file itself binds, registers, and
// exposes one coherent set of readings.
//
// It deliberately never calls refresh() on usable coordinates, so the harness
// cannot fire an outbound request, and never writes the service's cache file,
// so it leaves no reading behind for a later consumer to believe.
Item {
    id: root

    property int checks: 0
    property int failures: 0

    function check(label, actual, expected) {
        root.checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root.failures += 1
        console.log("FAIL:", label, "expected", expected, "got", actual)
    }

    Component.onCompleted: Qt.callLater(function() {
        // Referencing the singleton is the assertion: a QML error here (unknown
        // property, broken binding, missing import) fails to load and this file
        // never reports at all.
        var weather = Services.WeatherService

        // --- an unloaded service has a coherent absent state ---
        // Every derived field must agree that there is no reading, and no field
        // may claim one. An optional header reads this as unavailable.
        root.check("no reading is not available", weather.available, false)
        root.check("no reading has no temperature", isNaN(weather.temperature), true)
        root.check("no reading is stale", weather.isStale, true)
        root.check("no reading is not loading", weather.loading, false)
        root.check("no reading starts without an error", weather.lastError, "")
        root.check("absent state matches the pure module",
            ControlCenterLogic.weatherState({
                available: weather.available,
                temperature: weather.temperature,
                isStale: weather.isStale,
                loading: weather.loading,
                lastError: weather.lastError
            }), "unavailable")

        // --- a request already in flight is never doubled ---
        // Held rather than issued: this checks the guard without a network call.
        weather.loading = true
        root.check("refresh returns while loading", weather.refresh(), false)
        root.check("an in-flight refresh reads as loading", weather.loading, true)
        root.check("a loading header is loading", ControlCenterLogic.weatherState({
            available: weather.available,
            temperature: weather.temperature,
            loading: weather.loading,
            lastError: weather.lastError
        }), "loading")
        weather.loading = false

        // --- an unusable coordinate pair is refused, not pinned ---
        root.check("a named latitude is refused", weather.setCoordinates("north", "east"), false)
        root.check("an out-of-range latitude is refused", weather.setCoordinates(91, 0), false)
        root.check("an out-of-range longitude is refused", weather.setCoordinates(0, 181), false)
        // Blank input is a refusal, not latitude 0: Number("") is 0, so a
        // lenient parse would aim the reading at the Gulf of Guinea.
        root.check("a blank pair is refused", weather.setCoordinates("", ""), false)
        // The refusal must not leave a bad position behind.
        root.check("a refused pair leaves no coordinates ready",
            weather.coordinatesReady && !isFinite(weather.latitude), false)

        // --- an accepted pair is kept, and the report agrees with it ---
        // Reading the accepted flag back off a derived property in the same turn
        // as the write would report a successful override as refused, so this
        // asserts the stored values rather than the return value alone.
        root.check("a valid pair is accepted", weather.setCoordinates(31.2304, 121.4737), true)
        root.check("the accepted latitude is kept", weather.latitude, 31.2304)
        root.check("the accepted longitude is kept", weather.longitude, 121.4737)
        root.check("an accepted pair is ready", weather.coordinatesReady, true)
        root.check("an accepted pair forms a request",
            WeatherLogic.requestUrl(weather.latitude, weather.longitude) !== "", true)
        // A string pair from the settings form takes the same path.
        root.check("a string pair is accepted", weather.setCoordinates(" -33.87 ", "151.21"), true)
        root.check("the string latitude is stored", weather.latitude, -33.87)
        root.check("the string longitude is stored", weather.longitude, 151.21)
        // Clearing must hand control back to the settings coordinates.
        weather.clearCoordinates()
        root.check("clearing drops the override", weather.coordinatesReady,
            Services.SettingsService.locationCoordsValid)

        console.log("Totals:", root.checks - root.failures, "passed,", root.failures, "failed")
        Qt.quit()
    })
}