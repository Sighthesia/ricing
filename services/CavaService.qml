pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    readonly property string _homeDir: {
        const home = Quickshell.env("HOME")
        return home ? home : Quickshell.workingDirectory
    }
    readonly property string _cacheHome: {
        const cacheHome = Quickshell.env("XDG_CACHE_HOME")
        return cacheHome ? cacheHome : root._homeDir + "/.cache"
    }

    readonly property bool enabled: SettingsService.data.mediaControl.cavaEnabled
    readonly property int barCount: Math.max(1, SettingsService.data.mediaControl.cavaBars)
    readonly property int asciiMaxRange: Math.max(1, SettingsService.data.mediaControl.cavaAsciiMaxRange)
    readonly property int framerate: Math.max(1, SettingsService.data.mediaControl.cavaFramerate)
    readonly property bool available: root._cavaBinary !== ""
    readonly property bool healthy: root.enabled && root.available && !root._degraded && root.bars.length > 0
    readonly property bool degraded: root._degraded
    readonly property string cacheDir: root._cacheHome + "/dymicshell/"
    readonly property string configFile: root.cacheDir + "cava-media-control.conf"

    property var bars: []
    property string _cavaBinary: Qt.platform.os === "linux" ? "/usr/bin/cava" : ""
    property string _pulseSource: "auto"
    property bool _degraded: false

    function parseFrame(frame) {
        const trimmed = (frame || "").trim()
        if (trimmed === "")
            return []

        const values = trimmed.split(";").filter(value => value.trim() !== "")
        const normalized = []

        for (let index = 0; index < values.length; index++) {
            const rawValue = Number(values[index].trim())
            if (Number.isNaN(rawValue))
                return []

            normalized.push(Math.max(0, Math.min(1, rawValue / root.asciiMaxRange)))
        }

        return normalized
    }

    function applyFrame(frame) {
        const parsed = root.parseFrame(frame)

        if (parsed.length === 0) {
            root.bars = []
            root._degraded = true
            return []
        }

        root.bars = parsed
        root._degraded = false
        return parsed
    }

    function _configText() {
        return [
            "[general]",
            "framerate = " + root.framerate,
            "bars = " + root.barCount,
            "[input]",
            "method = pulse",
            "source = " + root._pulseSource,
            "[output]",
            "method = raw",
            "raw_target = /dev/stdout",
            "data_format = ascii",
            "ascii_max_range = " + root.asciiMaxRange,
            "bar_delimiter = 59",
            "frame_delimiter = 10"
        ].join("\n") + "\n"
    }

    function _writeConfig() {
        _configWriter.command = [
            "sh",
            "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"",
            "sh",
            root.cacheDir,
            root._configText(),
            root.configFile
        ]
        _configWriter.running = false
        _configWriter.running = true
    }

    function _restartProcess() {
        if (_cavaProcess.running)
            _cavaProcess.running = false

        root.bars = []

        if (!root.enabled || !root.available) {
            root._degraded = true
            return
        }

        root._writeConfig()
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.cacheDir])
        _detectCavaBinary.running = true
    }

    onEnabledChanged: root._restartProcess()
    onBarCountChanged: root._restartProcess()
    onAsciiMaxRangeChanged: root._restartProcess()
    onFramerateChanged: root._restartProcess()

    Process {
        id: _detectCavaBinary
        command: [
            "sh",
            "-c",
            "if command -v cava >/dev/null 2>&1; then "
                + "command -v cava; "
            + "elif [ -x /usr/bin/cava ]; then "
                + "printf '/usr/bin/cava\\n'; "
            + "elif [ -x /bin/cava ]; then "
                + "printf '/bin/cava\\n'; "
            + "fi"
        ]

        stdout: SplitParser {
            onRead: (line) => root._cavaBinary = line.trim()
        }

        onExited: () => {
            if (root.available)
                _detectPulseSource.running = true
            else
                root._degraded = true
        }
    }

    Process {
        id: _detectPulseSource
        command: [
            "sh",
            "-c",
            "pactl_bin=''; "
            + "if command -v pactl >/dev/null 2>&1; then "
                + "pactl_bin=$(command -v pactl); "
            + "elif [ -x /usr/bin/pactl ]; then "
                + "pactl_bin=/usr/bin/pactl; "
            + "fi; "
            + "if [ -n \"$pactl_bin\" ]; then "
                + "sink=$($pactl_bin info 2>/dev/null | awk -F': ' '/Default Sink/ { print $2; exit }'); "
                + "if [ -n \"$sink\" ]; then printf '%s.monitor\\n' \"$sink\"; fi; "
            + "fi"
        ]

        stdout: SplitParser {
            onRead: (line) => {
                const detectedSource = line.trim()
                root._pulseSource = detectedSource !== "" ? detectedSource : "auto"
            }
        }

        onExited: () => {
            if (root._pulseSource === "")
                root._pulseSource = "auto"

            root._restartProcess()
        }
    }

    Process {
        id: _configWriter

        onExited: (code) => {
            if (code !== 0) {
                root._degraded = true
                return
            }

            _cavaProcess.command = [root._cavaBinary, "-p", root.configFile]
            _cavaProcess.running = true
        }
    }

    Process {
        id: _cavaProcess

        stdout: SplitParser {
            onRead: (line) => root.applyFrame(line)
        }

        onExited: () => {
            root.bars = []
            if (root.enabled)
                root._degraded = true
        }
    }
}