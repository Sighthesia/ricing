pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Bridges Netease web lyric payloads into shared compact media state.
Singleton {
    id: root

    // FIXME: Keep this default port aligned with the userscript prototype.
    readonly property int _defaultPort: 18765
    readonly property string _helperOverride: (Quickshell.env("DYMICSHELL_NETEASE_WEB_LYRICS_CMD") || "").trim()
    readonly property bool _bundledHelperDisabled:
        (Quickshell.env("DYMICSHELL_NETEASE_WEB_LYRICS_DISABLE") || "").trim() === "1"
    readonly property string _bundledHelperPath: Quickshell.shellDir + "/scripts/netease_web_lyrics_bridge.py"
    readonly property string _portOverride: {
        const configured = (Quickshell.env("DYMICSHELL_NETEASE_WEB_LYRICS_PORT") || "").trim()
        return configured !== "" ? configured : String(root._defaultPort)
    }
    readonly property string _bundledHelperCommand:
        "export DYMICSHELL_NETEASE_WEB_LYRICS_PORT='"
        + root._portOverride.replace(/'/g, "'\"'\"'")
        + "'; if command -v python3 >/dev/null 2>&1; then exec python3 '"
        + root._bundledHelperPath
        + "'; else exit 0; fi"
    readonly property string helperCommand:
        root._helperOverride !== ""
            ? root._helperOverride
            : (root._bundledHelperDisabled ? "" : root._bundledHelperCommand)
    readonly property bool available: helperCommand !== ""
    readonly property bool running: _bridgeProcess.running

    property string songId: ""
    property string title: ""
    property string artist: ""
    property string playbackState: "stopped"
    property real progress: 0
    property int durationMs: 0
    property int positionMs: 0
    property string rawLyric: ""
    property string translatedLyric: ""
    property string currentLyric: ""
    property string nextLyric: ""
    property string currentTranslatedLyric: ""
    property string nextTranslatedLyric: ""
    property bool hasLyrics: false
    readonly property bool active:
        songId !== ""
            || title !== ""
            || artist !== ""
            || rawLyric !== ""
            || translatedLyric !== ""
            || currentLyric !== ""
            || nextLyric !== ""
            || currentTranslatedLyric !== ""
            || nextTranslatedLyric !== ""

    property var _lyricLines: []
    property var _translatedLyricLines: []
    property int _lastUpdateMs: 0
    property int _positionAnchorMs: 0
    property string _lastPayloadSignature: ""
    property bool _restartPending: false

    function _normalizeText(value) {
        return value != null ? String(value).trim() : ""
    }

    function _normalizeNumber(value, fallbackValue) {
        const parsed = Number(value)
        return Number.isFinite(parsed) ? parsed : fallbackValue
    }

    function _normalizeProgress(value) {
        const parsed = Number(value)
        if (!Number.isFinite(parsed))
            return 0

        return Math.max(0, Math.min(1, parsed))
    }

    function _normalizePlaybackState(value) {
        const normalized = root._normalizeText(value).toLowerCase()

        switch (normalized) {
        case "playing":
        case "play":
        case "1":
        case "true":
            return "playing"
        case "paused":
        case "pause":
        case "0":
        case "false":
            return "paused"
        case "stopped":
        case "stop":
        default:
            return "stopped"
        }
    }

    function _hasCurrentSession() {
        return root.songId !== ""
            || root.rawLyric !== ""
            || root.translatedLyric !== ""
            || root.currentLyric !== ""
            || root.nextLyric !== ""
            || root.currentTranslatedLyric !== ""
            || root.nextTranslatedLyric !== ""
    }

    function _isWeakerSessionPayload(nextSongId, nextTitle, nextArtist, nextRawLyric, nextTranslatedLyric) {
        return root._hasCurrentSession()
            && nextSongId === ""
            && nextRawLyric === ""
            && nextTranslatedLyric === ""
            && (nextTitle !== "" || nextArtist !== "")
    }

    function _effectivePositionMs() {
        if (root.playbackState !== "playing")
            return Math.max(0, root.positionMs)

        const anchorMs = root._positionAnchorMs > 0 ? root._positionAnchorMs : root._lastUpdateMs
        const elapsedMs = anchorMs > 0 ? Math.max(0, Date.now() - anchorMs) : 0
        const nextPositionMs = Math.max(0, root.positionMs + elapsedMs)
        if (root.durationMs <= 0)
            return nextPositionMs

        return Math.min(root.durationMs, nextPositionMs)
    }

    function _parseLyricLines(rawLyric) {
        const lines = []
        const source = root._normalizeText(rawLyric)
        if (source === "")
            return lines

        const timestampRegex = /\[(\d+):(\d+)(?:\.(\d{1,3}))?\]/g
        const sourceLines = source.split(/\r?\n/)

        for (let lineIndex = 0; lineIndex < sourceLines.length; lineIndex++) {
            const sourceLine = sourceLines[lineIndex]
            timestampRegex.lastIndex = 0

            let match = null
            const timestamps = []
            while ((match = timestampRegex.exec(sourceLine)) !== null) {
                const minutes = Number(match[1])
                const seconds = Number(match[2])
                const fraction = match[3] ? Number((match[3] + "00").slice(0, 3)) : 0
                if (!Number.isFinite(minutes) || !Number.isFinite(seconds))
                    continue

                timestamps.push((minutes * 60 * 1000) + (seconds * 1000) + fraction)
            }

            if (timestamps.length === 0)
                continue

            const text = sourceLine.replace(timestampRegex, "").trim()
            if (text === "")
                continue

            for (let i = 0; i < timestamps.length; i++)
                lines.push({ timeMs: timestamps[i], text: text })
        }

        lines.sort((a, b) => a.timeMs - b.timeMs)
        return lines
    }

    function _syncLyricWindow() {
        const lines = root._lyricLines
        if (!lines || lines.length === 0) {
            root.currentLyric = ""
            root.nextLyric = ""
        } else {
            let current = ""
            let next = ""
            const cursorMs = root._effectivePositionMs()

            for (let i = 0; i < lines.length; i++) {
                const line = lines[i]
                if (line.timeMs <= cursorMs) {
                    current = line.text
                    continue
                }

                next = line.text
                break
            }

            root.currentLyric = current
            root.nextLyric = next
        }

        const translatedLines = root._translatedLyricLines
        if (!translatedLines || translatedLines.length === 0) {
            root.currentTranslatedLyric = ""
            root.nextTranslatedLyric = ""
        } else {
            let currentTranslated = ""
            let nextTranslated = ""
            const cursorMs = root._effectivePositionMs()

            for (let i = 0; i < translatedLines.length; i++) {
                const line = translatedLines[i]
                if (line.timeMs <= cursorMs) {
                    currentTranslated = line.text
                    continue
                }

                nextTranslated = line.text
                break
            }

            root.currentTranslatedLyric = currentTranslated
            root.nextTranslatedLyric = nextTranslated
        }

        root.hasLyrics = root.currentLyric !== ""
            || root.nextLyric !== ""
            || root.currentTranslatedLyric !== ""
            || root.nextTranslatedLyric !== ""
            || root.rawLyric !== ""
            || root.translatedLyric !== ""

        root.progress = root.durationMs > 0
            ? Math.max(0, Math.min(1, root._effectivePositionMs() / root.durationMs))
            : 0
    }

    function _resetState() {
        root.songId = ""
        root.title = ""
        root.artist = ""
        root.playbackState = "stopped"
        root.progress = 0
        root.durationMs = 0
        root.positionMs = 0
        root.rawLyric = ""
        root.translatedLyric = ""
        root.currentLyric = ""
        root.nextLyric = ""
        root.currentTranslatedLyric = ""
        root.nextTranslatedLyric = ""
        root.hasLyrics = false
        root._lyricLines = []
        root._translatedLyricLines = []
        root._lastPayloadSignature = ""
        root._lastUpdateMs = 0
        root._positionAnchorMs = 0
    }

    function _applyPayload(payload) {
        const nextSongId = root._normalizeText(payload.songId || payload.id)
        const nextTitle = root._normalizeText(payload.title)
        const nextArtist = root._normalizeText(payload.artist)
        const nextPlaybackState = root._normalizePlaybackState(payload.playbackState)
        const nextProgress = root._normalizeProgress(payload.progress)
        const nextDurationMs = Math.max(0, Math.round(root._normalizeNumber(payload.durationMs != null ? payload.durationMs : payload.duration, 0)))
        const nextPositionMsRaw = root._normalizeNumber(payload.positionMs, NaN)
        const nextPositionMs = Number.isFinite(nextPositionMsRaw)
            ? Math.max(0, Math.round(nextPositionMsRaw))
            : (nextDurationMs > 0 ? Math.max(0, Math.round(nextProgress * nextDurationMs)) : 0)
        const nextRawLyric = root._normalizeText(payload.rawLyric || payload.lyric)
        const nextTranslatedLyric = root._normalizeText(payload.translatedLyric || payload.tlyric)
        const hasSessionContent = root.hasLyrics || root.rawLyric !== "" || root.translatedLyric !== ""
        const emptyMetadataPayload = nextSongId === "" && nextTitle === "" && nextArtist === ""
        const pauseSessionGap = hasSessionContent
            && emptyMetadataPayload
            && nextRawLyric === ""
            && nextTranslatedLyric === ""
            && nextPlaybackState === "paused"
        const weakPayload = root._isWeakerSessionPayload(
            nextSongId,
            nextTitle,
            nextArtist,
            nextRawLyric,
            nextTranslatedLyric
        )
        const metadataLooksSame =
            nextSongId === ""
                && nextTitle !== ""
                && nextTitle === root.title
                && ((nextArtist !== "" && nextArtist === root.artist)
                    || (nextArtist === "" && root.artist === ""))
        const metadataLooksDifferent =
            nextSongId === ""
                && ((nextTitle !== "" && nextTitle !== root.title)
                    || (nextArtist !== "" && nextArtist !== root.artist))
        const sessionSeemsSame =
            (nextSongId !== "" && nextSongId === root.songId)
            || (metadataLooksSame && hasSessionContent)
            || pauseSessionGap
        const resolvedSongId = nextSongId !== "" ? nextSongId : (sessionSeemsSame ? root.songId : "")
        const resolvedTitle = nextTitle !== "" ? nextTitle : (sessionSeemsSame ? root.title : "")
        const resolvedArtist = nextArtist !== "" ? nextArtist : (sessionSeemsSame ? root.artist : "")
        const preserveLyricsPayload =
            sessionSeemsSame
                && !metadataLooksDifferent
                && nextRawLyric === ""
                && nextTranslatedLyric === ""
        const resolvedRawLyric = nextRawLyric !== "" ? nextRawLyric : (preserveLyricsPayload ? root.rawLyric : "")
        const resolvedTranslatedLyric = nextTranslatedLyric !== ""
            ? nextTranslatedLyric
            : (preserveLyricsPayload ? root.translatedLyric : "")
        const sameSong = resolvedSongId !== "" && resolvedSongId === root.songId
        const hasTimeline = root.durationMs > 0 || root.positionMs > 0
        const invalidTimeline = nextDurationMs === 0 && nextPositionMs === 0
        const preserveTimeline = sessionSeemsSame && hasTimeline && invalidTimeline
        const pauseTimelineRegression = sessionSeemsSame
            && root.positionMs > 0
            && nextPlaybackState === "paused"
            && nextPositionMs === 0
            && nextPositionMs < root.positionMs
        const preservePlaybackState = sessionSeemsSame
            && root.playbackState !== "stopped"
            && nextPlaybackState === "stopped"
        const preserveCurrentSession = weakPayload
            && root.playbackState === "playing"
            && sessionSeemsSame
        const resolvedPlaybackState =
            (preserveCurrentSession || preserveTimeline || preservePlaybackState)
                ? root.playbackState
                : nextPlaybackState
        const preserveTimelinePosition = preserveCurrentSession || preserveTimeline || pauseTimelineRegression
        const resolvedProgress = preserveTimelinePosition ? root.progress : nextProgress
        const resolvedDurationMs = preserveTimelinePosition ? root.durationMs : nextDurationMs
        const resolvedPositionMs = preserveTimelinePosition ? root.positionMs : nextPositionMs
        const signature = [
            resolvedSongId,
            resolvedTitle,
            resolvedArtist,
            resolvedPlaybackState,
            String(resolvedPositionMs),
            String(resolvedDurationMs),
            resolvedRawLyric,
            resolvedTranslatedLyric
        ].join("|")

        root.songId = preserveCurrentSession ? root.songId : resolvedSongId
        root.title = preserveCurrentSession ? root.title : resolvedTitle
        root.artist = preserveCurrentSession ? root.artist : resolvedArtist
        root.playbackState = resolvedPlaybackState
        root.progress = resolvedProgress
        root.durationMs = resolvedDurationMs
        root.positionMs = resolvedPositionMs
        root.rawLyric = preserveCurrentSession ? root.rawLyric : resolvedRawLyric
        root.translatedLyric = preserveCurrentSession ? root.translatedLyric : resolvedTranslatedLyric
        root._lastUpdateMs = Date.now()
        if (!(preserveTimeline || pauseTimelineRegression))
            root._positionAnchorMs = root._lastUpdateMs
        else if (root.playbackState === "playing" && root._positionAnchorMs <= 0)
            root._positionAnchorMs = root._lastUpdateMs

        if (signature === root._lastPayloadSignature)
            return

        root._lastPayloadSignature = signature
        root._lyricLines = root._parseLyricLines(resolvedRawLyric)
        root._translatedLyricLines = root._parseLyricLines(resolvedTranslatedLyric)
        root._syncLyricWindow()
    }

    function _clearIfStale() {
        if (root._lastUpdateMs === 0)
            return

        if (Date.now() - root._lastUpdateMs <= root._staleTimeoutMs)
            return

        root._resetState()
    }

    function _handleLine(line) {
        const trimmed = root._normalizeText(line)
        if (trimmed === "")
            return

        try {
            root._applyPayload(JSON.parse(trimmed))
        } catch (error) {
            console.warn("[DymicShell:NeteaseWebLyricsService] Ignoring malformed payload")
        }
    }

    function _restartBridge() {
        if (!root.available || _bridgeProcess.running || root._restartPending)
            return

        root._restartPending = true
        _restartTimer.restart()
    }

    // FIXME: Make the stale timeout configurable if the bridge needs slower polling.
    readonly property int _staleTimeoutMs: 15000

    Component.onCompleted: {
        if (root.available)
            _bridgeProcess.running = true
    }

    Process {
        id: _bridgeProcess

        command: ["sh", "-c", root.helperCommand]
        running: false

        stdout: SplitParser {
            onRead: line => root._handleLine(line)
        }

        onExited: () => {
            if (root.active)
                root._clearIfStale()

            root._restartBridge()
        }
    }

    Timer {
        id: _restartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            root._restartPending = false
            if (!root.available || _bridgeProcess.running)
                return

            _bridgeProcess.running = true
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: {
            root._clearIfStale()
            root._syncLyricWindow()
        }
    }
}
