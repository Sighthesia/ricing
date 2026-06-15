pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "./" as Services

// Bridge NetEase web lyric payloads into a shared QML lyric timeline.
Singleton {
    id: root

    readonly property bool _debugLyricDisplay:
        (Quickshell.env("AFLOAT_MEDIA_LYRIC_DEBUG") || "").trim() === "1"
    readonly property int _defaultPort: 18765
    readonly property string _helperOverride: (Quickshell.env("AFLOAT_NETEASE_WEB_LYRICS_CMD") || "").trim()
    readonly property bool _bundledHelperDisabled:
        (Quickshell.env("AFLOAT_NETEASE_WEB_LYRICS_DISABLE") || "").trim() === "1"
    readonly property string _bundledHelperPath: Quickshell.shellDir + "/scripts/netease_web_lyrics_bridge.py"
    readonly property string _portOverride: {
        const configured = (Quickshell.env("AFLOAT_NETEASE_WEB_LYRICS_PORT") || "").trim()
        return configured !== "" ? configured : String(root._defaultPort)
    }
    readonly property string _bundledHelperCommand:
        "export AFLOAT_NETEASE_WEB_LYRICS_PORT='"
        + root._portOverride.replace(/'/g, "'\"'\"'")
        + "'; if command -v python3 >/dev/null 2>&1; then exec python3 '"
        + root._bundledHelperPath
        + "'; else exit 0; fi"
    readonly property string helperCommand:
        root._helperOverride !== ""
            ? root._helperOverride
            : (root._bundledHelperDisabled ? "" : root._bundledHelperCommand)
    readonly property bool available: helperCommand !== ""
    readonly property bool running: bridgeProcess.running
    readonly property int _staleTimeoutMs: 15000
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

    property string songId: ""
    property string title: ""
    property string artist: ""
    property string artUrl: ""
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
    property int currentLyricIndex: -1
    property int nextLyricIndex: -1
    property int currentTranslatedLyricIndex: -1
    property int nextTranslatedLyricIndex: -1
    property bool hasLyrics: false
    property var _lyricLines: []
    property var _translatedLyricLines: []
    property real _lastUpdateMs: 0
    property real _positionAnchorMs: 0
    property string _lastPayloadSignature: ""
    property bool _restartPending: false

    function _normalizedTrackKey(trackTitle, trackArtist) {
        const normalizedTitle = root._normalizedTrackTitle(trackTitle)
        if (normalizedTitle === "")
            return ""

        return [normalizedTitle, root._normalizedArtistKey(trackArtist)].join("|")
    }

    function _normalizedTrackTitle(value) {
        return root._normalizeText(value).toLowerCase().replace(/\s+/g, " ")
    }

    function _normalizedArtistTokens(value) {
        const normalized = root._normalizeText(value).toLowerCase().replace(/\s+/g, " ")
        if (normalized === "")
            return []

        return normalized
            .split(/\s*(?:,|，|\/|&|、|;|；| feat\.? | featuring )\s*/)
            .map(token => token.trim())
            .filter(token => token !== "")
    }

    function _normalizedArtistKey(value) {
        const tokens = root._normalizedArtistTokens(value)
        if (!tokens || tokens.length === 0)
            return ""

        const unique = []
        for (let index = 0; index < tokens.length; index += 1) {
            const token = tokens[index]
            if (unique.indexOf(token) === -1)
                unique.push(token)
        }

        unique.sort()
        return unique.join(",")
    }

    function _trackMetadataMatches(firstTitle, firstArtist, secondTitle, secondArtist) {
        const normalizedFirstTitle = root._normalizedTrackTitle(firstTitle)
        const normalizedSecondTitle = root._normalizedTrackTitle(secondTitle)
        if (normalizedFirstTitle === "" || normalizedSecondTitle === "")
            return false
        if (normalizedFirstTitle !== normalizedSecondTitle)
            return false

        const firstArtists = root._normalizedArtistTokens(firstArtist)
        const secondArtists = root._normalizedArtistTokens(secondArtist)
        if (firstArtists.length === 0 || secondArtists.length === 0)
            return true

        for (let firstIndex = 0; firstIndex < firstArtists.length; firstIndex += 1) {
            const firstToken = firstArtists[firstIndex]
            for (let secondIndex = 0; secondIndex < secondArtists.length; secondIndex += 1) {
                const secondToken = secondArtists[secondIndex]
                if (firstToken === secondToken || firstToken.indexOf(secondToken) !== -1 || secondToken.indexOf(firstToken) !== -1)
                    return true
            }
        }

        return false
    }

    function _shouldUseMediaTimeline() {
        if (!Services.MediaService.hasPlayer)
            return false

        return root._trackMetadataMatches(
            root.title,
            root.artist,
            Services.MediaService.title,
            Services.MediaService.artist
        )
    }

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

    function _shouldPreserveCurrentSession(nextSongId, nextRawLyric, nextTranslatedLyric, nextPlaybackState) {
        if (nextSongId !== "" || nextRawLyric !== "" || nextTranslatedLyric !== "")
            return false
        if (!root._hasCurrentSession())
            return false

        return root.playbackState !== "stopped" || nextPlaybackState !== "stopped"
    }

    function _effectivePositionMs() {
        if (root._shouldUseMediaTimeline()) {
            const mediaPositionMs = Math.max(0, Services.MediaService.positionMs)
            const resolvedPositionMs = Math.max(0, Math.max(root.positionMs, mediaPositionMs))
            if (root.durationMs <= 0)
                return resolvedPositionMs

            return Math.min(root.durationMs, resolvedPositionMs)
        }

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

        for (let lineIndex = 0; lineIndex < sourceLines.length; lineIndex += 1) {
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

            for (let index = 0; index < timestamps.length; index += 1)
                lines.push({ timeMs: timestamps[index], text: text })
        }

        lines.sort((a, b) => a.timeMs - b.timeMs)
        return lines
    }

    function _syncLyricWindow() {
        const previousOriginalCurrent = root.currentLyric
        const previousOriginalNext = root.nextLyric
        const previousTranslatedCurrent = root.currentTranslatedLyric
        const previousTranslatedNext = root.nextTranslatedLyric
        const previousOriginalCurrentIndex = root.currentLyricIndex
        const previousOriginalNextIndex = root.nextLyricIndex
        const previousTranslatedCurrentIndex = root.currentTranslatedLyricIndex
        const previousTranslatedNextIndex = root.nextTranslatedLyricIndex
        const lines = root._lyricLines

        if (!lines || lines.length === 0) {
            root.currentLyric = ""
            root.nextLyric = ""
            root.currentLyricIndex = -1
            root.nextLyricIndex = -1
        } else {
            let current = ""
            let next = ""
            let currentIndex = -1
            let nextIndex = -1
            const cursorMs = root._effectivePositionMs()

            for (let index = 0; index < lines.length; index += 1) {
                const line = lines[index]
                if (line.timeMs <= cursorMs) {
                    current = line.text
                    currentIndex = index
                    continue
                }

                next = line.text
                nextIndex = index
                break
            }

            root.currentLyric = current
            root.nextLyric = next
            root.currentLyricIndex = currentIndex
            root.nextLyricIndex = nextIndex
        }

        const translatedLines = root._translatedLyricLines
        if (!translatedLines || translatedLines.length === 0) {
            root.currentTranslatedLyric = ""
            root.nextTranslatedLyric = ""
            root.currentTranslatedLyricIndex = -1
            root.nextTranslatedLyricIndex = -1
        } else {
            let currentTranslated = ""
            let nextTranslated = ""
            let currentTranslatedIndex = -1
            let nextTranslatedIndex = -1
            const cursorMs = root._effectivePositionMs()

            for (let index = 0; index < translatedLines.length; index += 1) {
                const line = translatedLines[index]
                if (line.timeMs <= cursorMs) {
                    currentTranslated = line.text
                    currentTranslatedIndex = index
                    continue
                }

                nextTranslated = line.text
                nextTranslatedIndex = index
                break
            }

            root.currentTranslatedLyric = currentTranslated
            root.nextTranslatedLyric = nextTranslated
            root.currentTranslatedLyricIndex = currentTranslatedIndex
            root.nextTranslatedLyricIndex = nextTranslatedIndex
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

        if (root._debugLyricDisplay) {
            const changed = previousOriginalCurrent !== root.currentLyric
                || previousOriginalNext !== root.nextLyric
                || previousTranslatedCurrent !== root.currentTranslatedLyric
                || previousTranslatedNext !== root.nextTranslatedLyric
                || previousOriginalCurrentIndex !== root.currentLyricIndex
                || previousOriginalNextIndex !== root.nextLyricIndex
                || previousTranslatedCurrentIndex !== root.currentTranslatedLyricIndex
                || previousTranslatedNextIndex !== root.nextTranslatedLyricIndex

            console.log("[afloat:LyricWindow]", JSON.stringify({
                changed: changed,
                playbackState: root.playbackState,
                cursorMs: root._effectivePositionMs(),
                positionMs: root.positionMs,
                durationMs: root.durationMs,
                original: {
                    current: root.currentLyric,
                    next: root.nextLyric,
                    currentIndex: root.currentLyricIndex,
                    nextIndex: root.nextLyricIndex
                },
                translated: {
                    current: root.currentTranslatedLyric,
                    next: root.nextTranslatedLyric,
                    currentIndex: root.currentTranslatedLyricIndex,
                    nextIndex: root.nextTranslatedLyricIndex
                }
            }))
        }
    }

    function _resetState() {
        root.songId = ""
        root.title = ""
        root.artist = ""
        root.artUrl = ""
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
        root.currentLyricIndex = -1
        root.nextLyricIndex = -1
        root.currentTranslatedLyricIndex = -1
        root.nextTranslatedLyricIndex = -1
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
        const nextArtUrl = root._normalizeText(payload.artUrl || payload.coverUrl || payload.trackArtUrl)
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
        const weakPayload = root._isWeakerSessionPayload(nextSongId, nextTitle, nextArtist, nextRawLyric, nextTranslatedLyric)
        const metadataLooksSame = nextSongId === "" && root._trackMetadataMatches(nextTitle, nextArtist, root.title, root.artist)
        const metadataLooksDifferent = nextSongId === "" && (nextTitle !== "" || nextArtist !== "")
            && !root._trackMetadataMatches(nextTitle, nextArtist, root.title, root.artist)
        const sessionSeemsSame = (nextSongId !== "" && nextSongId === root.songId)
            || (metadataLooksSame && hasSessionContent)
            || pauseSessionGap
        const resolvedSongId = nextSongId !== "" ? nextSongId : (sessionSeemsSame ? root.songId : "")
        const resolvedTitle = nextTitle !== "" ? nextTitle : (sessionSeemsSame ? root.title : "")
        const resolvedArtist = nextArtist !== "" ? nextArtist : (sessionSeemsSame ? root.artist : "")
        const resolvedArtUrl = nextArtUrl !== "" ? nextArtUrl : (sessionSeemsSame ? root.artUrl : "")
        const preserveLyricsPayload = sessionSeemsSame && !metadataLooksDifferent
            && nextRawLyric === "" && nextTranslatedLyric === ""
        const resolvedRawLyric = nextRawLyric !== "" ? nextRawLyric : (preserveLyricsPayload ? root.rawLyric : "")
        const resolvedTranslatedLyric = nextTranslatedLyric !== "" ? nextTranslatedLyric : (preserveLyricsPayload ? root.translatedLyric : "")
        const hasTimeline = root.durationMs > 0 || root.positionMs > 0
        const invalidTimeline = nextDurationMs === 0 && nextPositionMs === 0
        const preserveTimeline = sessionSeemsSame && hasTimeline && invalidTimeline
        const pauseTimelineRegression = sessionSeemsSame && root.positionMs > 0 && nextPlaybackState === "paused"
            && nextPositionMs === 0 && nextPositionMs < root.positionMs
        const preservePlaybackState = sessionSeemsSame && root.playbackState !== "stopped" && nextPlaybackState === "stopped"
        const preserveCurrentSession = root._shouldPreserveCurrentSession(nextSongId, nextRawLyric, nextTranslatedLyric, nextPlaybackState)
            && (weakPayload || metadataLooksDifferent || pauseSessionGap)
        const resolvedPlaybackState = (preserveCurrentSession || preserveTimeline || preservePlaybackState)
            ? root.playbackState : nextPlaybackState
        const preserveTimelinePosition = preserveCurrentSession || preserveTimeline || pauseTimelineRegression
        const resolvedProgress = preserveTimelinePosition ? root.progress : nextProgress
        const resolvedDurationMs = preserveTimelinePosition ? root.durationMs : nextDurationMs
        const resolvedPositionMs = preserveTimelinePosition ? root.positionMs : nextPositionMs
        const signature = [
            resolvedSongId,
            resolvedTitle,
            resolvedArtist,
            resolvedArtUrl,
            resolvedPlaybackState,
            String(resolvedPositionMs),
            String(resolvedDurationMs),
            resolvedRawLyric,
            resolvedTranslatedLyric
        ].join("|")

        root.songId = preserveCurrentSession ? root.songId : resolvedSongId
        root.title = preserveCurrentSession ? root.title : resolvedTitle
        root.artist = preserveCurrentSession ? root.artist : resolvedArtist
        root.artUrl = preserveCurrentSession ? root.artUrl : resolvedArtUrl
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
            console.warn("[afloat:NeteaseWebLyricsService] Ignoring malformed payload")
        }
    }

    function _restartBridge() {
        if (!root.available || bridgeProcess.running || root._restartPending)
            return

        root._restartPending = true
        restartTimer.restart()
    }

    Component.onCompleted: {
        if (root.available)
            bridgeProcess.running = true
    }

    // Keep the helper process attached to the lyric service lifecycle.
    Process {
        id: bridgeProcess

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
        id: restartTimer

        interval: 1000
        repeat: false
        onTriggered: {
            root._restartPending = false
            if (!root.available || bridgeProcess.running)
                return

            bridgeProcess.running = true
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
