pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Resolves city names into coordinates for sunrise/sunset scheduling.
Singleton {
    id: root

    signal cityResolved(string city, real latitude, real longitude, string displayName)
    signal cityResolveFailed(string city, string reason)

    property string lookupState: "idle"
    property string lookupStatusText: "输入城市后自动解析"
    property string lastResolvedCity: ""
    property real lastResolvedLatitude: 0.0
    property real lastResolvedLongitude: 0.0
    property string lastResolvedDisplayName: ""
    property string lastError: ""
    property string _pendingCity: ""
    property string _activeCity: ""
    property string _stdoutBuffer: ""
    property bool _suppressExitFailure: false
    readonly property string _lookupScript:
        "import json, sys, urllib.parse, urllib.request, urllib.error\n"
        + "city = sys.argv[1].strip()\n"
        + "headers = {'User-Agent': 'DymicShell/1.0'}\n"
        + "providers = [\n"
        + "    ('open-meteo', 'https://geocoding-api.open-meteo.com/v1/search?' + urllib.parse.urlencode({'name': city, 'count': 1, 'language': 'zh', 'format': 'json'})),\n"
        + "    ('nominatim', 'https://nominatim.openstreetmap.org/search?' + urllib.parse.urlencode({'q': city, 'format': 'jsonv2', 'limit': 1}))\n"
        + "]\n"
        + "last_error = 'city not found'\n"
        + "for provider, url in providers:\n"
        + "    try:\n"
        + "        req = urllib.request.Request(url, headers=headers)\n"
        + "        with urllib.request.urlopen(req, timeout=4) as response:\n"
        + "            payload = json.load(response)\n"
        + "        if provider == 'open-meteo':\n"
        + "            results = payload.get('results') or []\n"
        + "            if results:\n"
        + "                item = results[0]\n"
        + "                print(json.dumps({'ok': True, 'provider': provider, 'lat': item.get('latitude'), 'lon': item.get('longitude'), 'display_name': item.get('name', '') + ((', ' + item.get('country', '')) if item.get('country') else '')}))\n"
        + "                sys.exit(0)\n"
        + "            last_error = 'city not found'\n"
        + "        else:\n"
        + "            if payload:\n"
        + "                item = payload[0]\n"
        + "                print(json.dumps({'ok': True, 'provider': provider, 'lat': item.get('lat'), 'lon': item.get('lon'), 'display_name': item.get('display_name', '')}))\n"
        + "                sys.exit(0)\n"
        + "            last_error = 'city not found'\n"
        + "    except urllib.error.URLError as exc:\n"
        + "        last_error = 'network timeout' if 'timed out' in str(exc.reason).lower() else 'network unavailable'\n"
        + "    except TimeoutError:\n"
        + "        last_error = 'network timeout'\n"
        + "    except Exception:\n"
        + "        last_error = 'provider error'\n"
        + "print(json.dumps({'ok': False, 'reason': last_error}))\n"

    Timer {
        id: lookupDebounceTimer
        interval: 450
        repeat: false
        onTriggered: root.lookupCity(root._pendingCity)
    }

    Process {
        id: lookupProcess

        stdout: SplitParser {
            onRead: data => root._stdoutBuffer += data
        }

        stderr: SplitParser {
            onRead: data => console.warn("[DymicShell:GeocodingService] geocode stderr:", data.trim())
        }

        onExited: function(exitCode, exitStatus) {
            if (root._suppressExitFailure) {
                root._suppressExitFailure = false
                return
            }

            if (exitCode !== 0) {
                root._failLookup(root._activeCity, "geocode lookup failed with code " + exitCode)
                return
            }

            root._handleLookupOutput(root._stdoutBuffer)
        }
    }

    function requestCityLookup(city) {
        const normalized = city.trim().replace(/\s+/g, " ")
        root._pendingCity = normalized

        if (normalized === "") {
            lookupDebounceTimer.stop()
            if (lookupProcess.running) {
                root._suppressExitFailure = true
                lookupProcess.running = false
            }
            root.lookupState = "idle"
            root.lookupStatusText = "输入城市后自动解析"
            root.lastError = ""
            return
        }

        root.lookupState = "typing"
        root.lookupStatusText = "等待解析 “" + normalized + "”"
        root.lastError = ""
        lookupDebounceTimer.restart()
    }

    function lookupCity(city) {
        const normalized = city.trim().replace(/\s+/g, " ")
        if (normalized === "") {
            root._failLookup(city, "city name is empty")
            return
        }

        root._pendingCity = normalized
        root._activeCity = normalized
        root._stdoutBuffer = ""
        root.lookupState = "loading"
        root.lookupStatusText = "正在解析 “" + normalized + "”"
        root.lastError = ""

        if (lookupProcess.running) {
            root._suppressExitFailure = true
            lookupProcess.running = false
        }

        lookupProcess.command = [
            "python3",
            "-c",
            root._lookupScript,
            normalized
        ]
        lookupProcess.running = true
    }

    function _handleLookupOutput(data) {
        const text = (data || "").trim()
        if (text === "")
            return root._failLookup(root._activeCity, "empty geocode response")

        try {
            const parsed = JSON.parse(text)
            if (!parsed.ok) {
                root._failLookup(root._activeCity, root._friendlyReason(String(parsed.reason || "provider error")))
                return
            }

            const latitude = Number(parsed.lat)
            const longitude = Number(parsed.lon)
            const displayName = String(parsed.display_name || "")
            const provider = String(parsed.provider || "")

            if (!isFinite(latitude) || !isFinite(longitude)) {
                root._failLookup(root._activeCity, "未找到可用坐标")
                return
            }

            root.lookupState = "success"
            root.lookupStatusText = displayName !== ""
                ? "已解析: " + displayName + " (" + latitude.toFixed(2) + ", " + longitude.toFixed(2) + ")"
                : "已解析: " + root._activeCity + " (" + latitude.toFixed(2) + ", " + longitude.toFixed(2) + ")"
            if (provider !== "")
                root.lookupStatusText += " [" + provider + "]"
            root.lastError = ""
            root.lastResolvedCity = root._activeCity
            root.lastResolvedLatitude = latitude
            root.lastResolvedLongitude = longitude
            root.lastResolvedDisplayName = displayName
            root.cityResolved(root._activeCity, latitude, longitude, displayName)
        } catch (e) {
            root._failLookup(root._activeCity, "解析返回失败")
        }
    }

    function _friendlyReason(reason) {
        const normalized = String(reason || "").toLowerCase()
        if (normalized === "network timeout")
            return "网络超时，可稍后重试或改用经纬度"
        if (normalized === "network unavailable")
            return "网络不可用，可改用经纬度"
        if (normalized === "city not found")
            return "未找到该城市，请尝试英文名或更完整地名"
        if (normalized === "provider error")
            return "地理编码服务暂时不可用"

        return String(reason || "解析失败")
    }

    function _failLookup(city, reason) {
        root.lookupState = "error"
        root.lookupStatusText = "解析失败: " + (city || "未命名城市") + "，" + reason
        root.lastError = reason
        root.cityResolveFailed(city, reason)
    }
}
