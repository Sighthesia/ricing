pragma Singleton
import QtQuick
import "./" as Services
import "SolarCalc.js" as SolarCalc

// Resolve city names to coordinates for location-driven sunrise/sunset.
// Reference: noctalia-shell Services/Location/LocationService.qml geocodes
// via api.noctalia.dev then reads daily sunrise/sunset from Open-Meteo.
// Afloat uses the free Open-Meteo geocoding endpoint (no key) and derives
// the timetable offline via SolarCalc so auto theme works without network
// after the one-time resolution.
QtObject {
    id: root

    // True while a geocode request is in flight.
    property bool isGeocoding: false
    // Last geocode failure, empty on success/idle.
    property string lastError: ""
    // Human-readable "Name, Country" of the last resolved city.
    property string displayName: ""
    // Mirrors SettingsService validity so panels can gate on one flag.
    readonly property bool coordinatesReady: Services.SettingsService.locationCoordsValid

    // Open-Meteo free geocoding (same provider family noctalia uses for
    // weather): https://geocoding-api.open-meteo.com/v1/search
    function geocodeUrl(city) {
        return "https://geocoding-api.open-meteo.com/v1/search?name="
            + encodeURIComponent(String(city).trim()) + "&count=1&language=zh&format=json"
    }

    function clearError() {
        lastError = ""
    }

    function clearCity() {
        Services.SettingsService.appearance.autoCity = ""
        displayName = ""
        lastError = ""
    }

    // Resolve a city name and store its coordinates into appearance settings.
    // Empty input clears the stored city without touching manual coordinates.
    // Success announces in the bar message band; failures stay inline under
    // the city field (lastError) so a typo never spams notifications.
    function geocodeCity(city) {
        var name = String(city == null ? "" : city).trim()
        if (name === "") {
            clearCity()
            return
        }
        if (isGeocoding)
            return
        isGeocoding = true
        lastError = ""
        var xhr = new XMLHttpRequest()
        xhr.timeout = 12000
        xhr.ontimeout = function () {
            root.isGeocoding = false
            root._fail("城市解析超时，检查网络后重试")
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            root.isGeocoding = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var first = data && data.results && data.results.length > 0 ? data.results[0] : null
                    if (first && isFinite(Number(first.latitude)) && isFinite(Number(first.longitude))) {
                        var lat = Number(first.latitude)
                        var lon = Number(first.longitude)
                        if (SolarCalc.isValidLatitude(lat) && SolarCalc.isValidLongitude(lon)) {
                            Services.SettingsService.appearance.autoCity = name
                            Services.SettingsService.appearance.autoLatitude = String(lat.toFixed(4))
                            Services.SettingsService.appearance.autoLongitude = String(lon.toFixed(4))
                            root.displayName = (first.name || name)
                                + (first.country ? ", " + first.country : "")
                            Services.SettingsService.save()
                            var times = SolarCalc.sunTimesForDate(new Date(), lat, lon)
                            Services.TransientMessageService.announce("已定位到 " + root.displayName,
                                "日出 " + times.sunrise + " · 日落 " + times.sunset)
                            return
                        }
                    }
                    root._fail("未找到该城市「" + name + "」，换个写法试试")
                } catch (e) {
                    root._fail("城市结果解析失败，稍后重试")
                }
            } else {
                root._fail("城市解析失败（网络 " + xhr.status + "），检查网络后重试")
            }
        }
        xhr.open("GET", geocodeUrl(name))
        try {
            xhr.send()
        } catch (e) {
            root.isGeocoding = false
            root._fail("城市解析请求失败，检查网络后重试")
        }
    }

    // Record the failure for the inline row hint only (no toast).
    function _fail(message) {
        root.lastError = message
        console.warn("LocationService:", message)
    }
}
