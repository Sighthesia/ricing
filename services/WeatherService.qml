pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services
import "weather/WeatherLogic.js" as WeatherLogic

// Optional current-weather adapter for the control center's header.
//
// It is deliberately cache-first and non-blocking: the reading is written to
// disk on every success, construction adopts that file without waiting for the
// network, and the first refresh only happens once coordinates validate. A
// refresh that fails leaves the previous reading in place and reports through
// lastError, so the header degrades to a stale reading instead of blanking.
// That is the contract ControlCenterLogic.weatherState() consumes: it reads
// `lastError` and reports "stale" rather than "unavailable" when a cached value
// survives a failure.
//
// Provider: the free Open-Meteo current-weather endpoint, the same provider
// family services/LocationService.qml already uses for sunrise and sunset. No
// key, so there is nothing to configure before the header can work.
Singleton {
    id: root

    // --- Public reading state ---
    // True while a request is in flight. The header shows a loading state
    // rather than an empty block, because a request that has not landed is not
    // an absence.
    property bool loading: false
    // Last refresh failure, empty on success and idle. Never cleared by a later
    // state change: only a successful refresh clears it.
    property string lastError: ""

    // The last usable reading, replaced wholesale so QML bindings follow. A
    // binding cannot observe in-place mutation of a JS object, so this is
    // never edited field by field.
    property var _cache: ({})

    // Manual coordinate override, empty when the settings coordinates are used.
    property real _manualLatitude: Number.NaN
    property real _manualLongitude: Number.NaN

    // Slow tick so a reading crosses into stale on its own. Without it
    // `isStale` would only change when something else wrote a property.
    property int _clockTick: 0

    // The single derivation of public state, so temperature/condition/location/
    // updatedAt/isStale/available can never disagree about one reading.
    readonly property var _state: {
        root._clockTick
        return WeatherLogic.cacheState(root._cache, Date.now(), root.loading)
    }
    // True once a reading exists, however old. A stale reading is still
    // available: the header keeps showing it rather than dropping to an empty
    // state after a failed refresh.
    readonly property bool available: _state.available
    // Degrees celsius; NaN when no reading exists.
    readonly property real temperature: _state.temperature
    // One of WeatherLogic's stable labels ("clear", "partly-cloudy", "cloudy",
    // "rain", "snow", "storm", "unknown").
    readonly property string condition: _state.condition
    // Place name derived from the response's timezone, "" when unknown.
    readonly property string location: _state.location
    // Epoch ms of the reading.
    readonly property int updatedAt: _state.updatedAt
    // True once the reading is older than WeatherLogic.cacheTtlMs.
    readonly property bool isStale: _state.isStale

    // --- Coordinates ---
    // A manual override only counts when it validates through the same
    // coordinate contract SettingsService.locationCoordsValid uses, so a typo
    // cannot buy a request at latitude 999.
    readonly property bool _manualCoordinatesValid: WeatherLogic.hasCoordinates(
        _manualLatitude, _manualLongitude)
    // True when a request can actually be formed.
    readonly property bool coordinatesReady: _manualCoordinatesValid
        || Services.SettingsService.locationCoordsValid
    readonly property real latitude: _manualCoordinatesValid
        ? _manualLatitude
        : (Services.SettingsService.locationCoordsValid
            ? parseFloat(Services.SettingsService.appearance.autoLatitude)
            : Number.NaN)
    readonly property real longitude: _manualCoordinatesValid
        ? _manualLongitude
        : (Services.SettingsService.locationCoordsValid
            ? parseFloat(Services.SettingsService.appearance.autoLongitude)
            : Number.NaN)

    // Override the coordinates used for refreshes, e.g. for a place the user
    // has not saved into settings. Invalid input clears the override and falls
    // back to the settings coordinates rather than pinning a bad position.
    function setCoordinates(latitude, longitude) {
        // WeatherLogic is the single source of truth for "can this form a
        // request", so an accepted pair is exactly one requestUrl() will build.
        // A rejected pair clears the override rather than leaving the previous
        // one in place, so a typo cannot silently keep showing the old place.
        //
        // The accepted flag is returned from the same check that assigned the
        // fields, never read back off _manualCoordinatesValid: a QML binding
        // derived from a property that was just written in this turn can still
        // answer with its previous value, which would report a successful
        // override as refused.
        var accepted = WeatherLogic.hasCoordinates(latitude, longitude)
        _manualLatitude = accepted ? parseFloat(latitude) : Number.NaN
        _manualLongitude = accepted ? parseFloat(longitude) : Number.NaN
        // Coordinates change what the next request should be, so ask for it
        // once the settings cascade has settled.
        _coordinateChangedTimer.restart()
        return accepted
    }

    // Drop the manual override and follow the saved coordinates again.
    function clearCoordinates() {
        _manualLatitude = Number.NaN
        _manualLongitude = Number.NaN
        _coordinateChangedTimer.restart()
    }

    // Request a reading now. Returns whether a request was actually started, so
    // a caller can tell a skipped refresh (already loading, no coordinates, no
    // formable URL) from a real one.
    //
    // Every early return here is a deliberate no-network path: this is called
    // on construction and on a repeating timer, so a shell without configured
    // coordinates must not queue requests that cannot succeed.
    function refresh() {
        if (root.loading)
            return false
        if (!root.coordinatesReady)
            return false
        var url = WeatherLogic.requestUrl(root.latitude, root.longitude)
        if (url === "")
            return false

        root.loading = true
        var xhr = new XMLHttpRequest()
        // Bounded so a stalled network cannot leave the header loading forever.
        xhr.timeout = 10000
        xhr.ontimeout = function () {
            root._endRequest()
            root._fail("天气请求超时，稍后自动重试")
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            root._endRequest()
            if (xhr.status !== 200) {
                root._fail("天气请求失败（网络 " + xhr.status + "），稍后自动重试")
                return
            }
            var parsed = WeatherLogic.parseResponse(xhr.responseText, Date.now())
            if (!parsed.ok) {
                root._fail(parsed.error)
                return
            }
            root._adopt(parsed)
        }
        try {
            xhr.open("GET", url)
            xhr.send()
        } catch (err) {
            root._endRequest()
            root._fail("天气请求失败，稍后自动重试")
        }
        return true
    }

    // Clear the reported failure without discarding the reading it happened on.
    function clearError() {
        root.lastError = ""
    }

    // A failure records the reason and nothing else. The previous cache is left
    // exactly as it was, so `available` and `temperature` keep reporting the
    // last reading and ControlCenterLogic reads it as "stale".
    function _fail(message) {
        root.lastError = String(message)
        console.warn("WeatherService:", message)
    }

    // Request state is released before the result is applied, so a consumer
    // reading `loading` inside the same turn as the new reading sees the
    // finished state rather than a request that is about to report a value.
    function _endRequest() {
        root.loading = false
    }

    // Adopt a parsed reading and persist the whole cache record.
    function _adopt(reading) {
        root._cache = {
            temperature: reading.temperature,
            condition: reading.condition,
            location: reading.location,
            updatedAt: reading.updatedAt
        }
        root.lastError = ""
        _persist()
    }

    // Replace the whole cache file in one write. There is no incremental update
    // to go half-applied: a reader either sees the previous complete record or
    // the new one.
    function _persist() {
        weatherCacheFile.setText(JSON.stringify({
            temperature: root._cache.temperature,
            condition: root._cache.condition,
            location: root._cache.location,
            updatedAt: root._cache.updatedAt
        }))
    }

    // Adopt the persisted record. Guarded so a late async load cannot overwrite
    // a reading that a refresh already installed.
    function _adoptPersisted(text) {
        if (root._cache && root._cache.temperature !== undefined)
            return
        var parsed = null
        try {
            parsed = text ? JSON.parse(String(text)) : null
        } catch (err) {
            console.warn("WeatherService: unreadable weather-cache.json:", err)
            return
        }
        if (parsed == null || typeof parsed !== "object")
            return
        var state = WeatherLogic.cacheState(parsed, Date.now())
        // An unreadable cache file is not an error worth reporting: the header
        // simply has nothing yet and the first refresh will fill it.
        if (!state.available)
            return
        root._cache = {
            temperature: state.temperature,
            condition: state.condition,
            location: state.location,
            updatedAt: state.updatedAt
        }
    }

    // The persisted reading, loaded at construction. blockLoading keeps the read
    // on the construction path so a cached reading is already adopted by the
    // time the first consumer reads it.
    property FileView weatherCacheFile: FileView {
        id: weatherCacheFile

        path: Quickshell.cacheDir + "/weather-cache.json"
        blockLoading: true
        watchChanges: false
        onLoaded: root._adoptPersisted(weatherCacheFile.text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("WeatherService: failed to load weather-cache.json, error =", error)
            // A missing cache is a valid empty state; the header reads as
            // unavailable until the first refresh lands.
            root._adoptPersisted("")
        }
    }

    // Refresh cadence. The period is the reading's own TTL, so the cache is
    // replaced at the moment it would otherwise go stale rather than drifting.
    property Timer _refreshTimer: Timer {
        interval: WeatherLogic.cacheTtlMs
        repeat: true
        running: true
        onTriggered: {
            // This timer also runs before coordinates exist, so gate here as
            // well as inside refresh().
            if (root.coordinatesReady)
                root.refresh()
        }
    }

    // The timer is 30 minutes long, so a first refresh would otherwise have to
    // wait for the whole TTL to lapse. This short first attempt is what makes
    // the reading appear soon after the shell starts, and it is a no-op until
    // coordinates validate.
    property Timer _firstRefreshTimer: Timer {
        interval: 1500
        repeat: false
        onTriggered: {
            if (root.coordinatesReady)
                root.refresh()
        }
    }

    // Coordinate edits land inside a settings cascade, so the refresh is asked
    // for one event-loop turn later: reading `coordinatesReady` in the same
    // turn as the change would see the pre-change value and refresh the old
    // position.
    property Timer _coordinateChangedTimer: Timer {
        interval: 0
        repeat: false
        onTriggered: root.refresh()
    }

    // Retires the reading as it ages, so `isStale` flips without another write.
    property Timer _clockTimer: Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root._clockTick += 1
    }

    property Connections _settingsConnection: Connections {
        target: Services.SettingsService
        function onSettingsReadyChanged() {
            // The persisted coordinates arrive with the settings file, so the
            // first refresh waits for the file rather than for a fixed delay.
            _firstRefreshTimer.restart()
        }
    }

    property Connections _appearanceConnection: Connections {
        target: Services.SettingsService.appearance
        function onAutoLatitudeChanged() { root._coordinateChangedTimer.restart() }
        function onAutoLongitudeChanged() { root._coordinateChangedTimer.restart() }
    }

    Component.onCompleted: {
        // blockLoading usually completes before this runs; adopt now if so,
        // otherwise onLoaded covers the async landing.
        if (weatherCacheFile.loaded)
            root._adoptPersisted(weatherCacheFile.text())
        _firstRefreshTimer.restart()
    }
}