pragma Singleton

import Quickshell
import QtQuick
import "./" as Services

// Merge MPRIS media state with NetEase lyric state for compact bar rendering.
Singleton {
    id: root

    readonly property bool preferLyrics: true
    readonly property bool preferTranslatedLyrics: true
    readonly property string _lyricsMetadataKey: root._normalizedTrackKey(
        Services.NeteaseWebLyricsService.title,
        Services.NeteaseWebLyricsService.artist
    )
    readonly property string _lyricsSessionKey:
        Services.NeteaseWebLyricsService.songId !== ""
            ? "id:" + Services.NeteaseWebLyricsService.songId
            : (root._lyricsMetadataKey !== "" ? "meta:" + root._lyricsMetadataKey : "")
    readonly property string _playerTrackKey: Services.MediaService.hasPlayer
        ? root._normalizedTrackKey(Services.MediaService.title, Services.MediaService.artist)
        : ""
    readonly property bool _lyricsSignalActive:
        root.preferLyrics
            && (Services.NeteaseWebLyricsService.active
                || Services.NeteaseWebLyricsService.hasLyrics
                || Services.NeteaseWebLyricsService.currentLyric !== ""
                || Services.NeteaseWebLyricsService.nextLyric !== ""
                || Services.NeteaseWebLyricsService.currentTranslatedLyric !== ""
                || Services.NeteaseWebLyricsService.nextTranslatedLyric !== "")
    readonly property bool _preferLyricsMediaSource: root._lyricsSourceLatched

    property bool _lyricsSourceLatched: false
    property string _latchedLyricsSessionKey: ""
    property string _latchedPlayerTrackKey: ""
    property string _latchedSourceTrackKey: ""
    property string _stableCurrentLyric: ""
    property string _stableNextLyric: ""
    property string _stableCurrentTranslatedLyric: ""
    property string _stableNextTranslatedLyric: ""
    property string _compactDisplayedLyric: ""
    property string _compactDisplayedLyricKey: ""
    property string _compactDisplayedTranslatedLyric: ""
    property string _compactDisplayedTranslatedLyricKey: ""
    property string _compactDisplayedTrack: ""
    property string _compactDisplayedLyricsSessionKey: ""
    property string _compactDisplayedLyricsPlayerTrackKey: ""

    readonly property bool hasMedia:
        Services.MediaService.hasPlayer || Services.NeteaseWebLyricsService.active || root._preferLyricsMediaSource
    readonly property string title: root._preferLyricsMediaSource
        ? (Services.NeteaseWebLyricsService.title !== ""
            ? Services.NeteaseWebLyricsService.title
            : (Services.MediaService.hasPlayer ? Services.MediaService.title : ""))
        : (Services.MediaService.hasPlayer ? Services.MediaService.title : Services.NeteaseWebLyricsService.title)
    readonly property string artist: root._preferLyricsMediaSource
        ? (Services.NeteaseWebLyricsService.artist !== ""
            ? Services.NeteaseWebLyricsService.artist
            : (Services.MediaService.hasPlayer ? Services.MediaService.artist : ""))
        : (Services.MediaService.hasPlayer ? Services.MediaService.artist : Services.NeteaseWebLyricsService.artist)
    readonly property string artUrl:
        Services.MediaService.hasPlayer && Services.MediaService.artUrl !== ""
            ? Services.MediaService.artUrl
            : (Services.NeteaseWebLyricsService.artUrl !== "" ? Services.NeteaseWebLyricsService.artUrl : "")
    readonly property string playerName: Services.MediaService.hasPlayer ? Services.MediaService.playerName : ""
    readonly property string playbackState: root._preferLyricsMediaSource
        ? ((Services.MediaService.hasPlayer && Services.MediaService.playbackState !== "playing")
            ? Services.MediaService.playbackState
            : ((Services.NeteaseWebLyricsService.playbackState !== "stopped" || !Services.MediaService.hasPlayer)
                ? Services.NeteaseWebLyricsService.playbackState
                : Services.MediaService.playbackState))
        : (Services.MediaService.hasPlayer ? Services.MediaService.playbackState : Services.NeteaseWebLyricsService.playbackState)
    readonly property int positionMs: root._preferLyricsMediaSource
        ? ((Services.MediaService.hasPlayer && Services.MediaService.playbackState !== "playing")
            ? Services.MediaService.positionMs
            : ((Services.NeteaseWebLyricsService.durationMs > 0 || Services.NeteaseWebLyricsService.positionMs > 0 || !Services.MediaService.hasPlayer)
                ? Services.NeteaseWebLyricsService.positionMs
                : Services.MediaService.positionMs))
        : (Services.MediaService.hasPlayer ? Services.MediaService.positionMs : Services.NeteaseWebLyricsService.positionMs)
    readonly property int lengthMs: root._preferLyricsMediaSource
        ? ((Services.MediaService.hasPlayer && Services.MediaService.playbackState !== "playing")
            ? Services.MediaService.lengthMs
            : ((Services.NeteaseWebLyricsService.durationMs > 0 || !Services.MediaService.hasPlayer)
                ? Services.NeteaseWebLyricsService.durationMs
                : Services.MediaService.lengthMs))
        : (Services.MediaService.hasPlayer ? Services.MediaService.lengthMs : Services.NeteaseWebLyricsService.durationMs)
    readonly property bool canGoPrevious: Services.MediaService.hasPlayer ? Services.MediaService.canGoPrevious : false
    readonly property bool canTogglePlayback: Services.MediaService.hasPlayer ? Services.MediaService.canTogglePlayback : false
    readonly property bool canGoNext: Services.MediaService.hasPlayer ? Services.MediaService.canGoNext : false
    readonly property bool canSeek: Services.MediaService.hasPlayer ? Services.MediaService.canSeek : false
    readonly property string currentLyric:
        Services.NeteaseWebLyricsService.currentLyric !== ""
            ? Services.NeteaseWebLyricsService.currentLyric
            : ((Services.NeteaseWebLyricsService.currentLyric === ""
                    && Services.NeteaseWebLyricsService.nextLyric === ""
                    && root._preferLyricsMediaSource)
                ? root._stableCurrentLyric
                : "")
    readonly property string nextLyric:
        Services.NeteaseWebLyricsService.nextLyric !== ""
            ? Services.NeteaseWebLyricsService.nextLyric
            : ((Services.NeteaseWebLyricsService.currentLyric === ""
                    && Services.NeteaseWebLyricsService.nextLyric === ""
                    && root._preferLyricsMediaSource)
                ? root._stableNextLyric
                : "")
    readonly property string currentTranslatedLyric:
        Services.NeteaseWebLyricsService.currentTranslatedLyric !== ""
            ? Services.NeteaseWebLyricsService.currentTranslatedLyric
            : ((Services.NeteaseWebLyricsService.currentTranslatedLyric === ""
                    && Services.NeteaseWebLyricsService.nextTranslatedLyric === ""
                    && root._preferLyricsMediaSource)
                ? root._stableCurrentTranslatedLyric
                : "")
    readonly property string nextTranslatedLyric:
        Services.NeteaseWebLyricsService.nextTranslatedLyric !== ""
            ? Services.NeteaseWebLyricsService.nextTranslatedLyric
            : ((Services.NeteaseWebLyricsService.currentTranslatedLyric === ""
                    && Services.NeteaseWebLyricsService.nextTranslatedLyric === ""
                    && root._preferLyricsMediaSource)
                ? root._stableNextTranslatedLyric
                : "")
    readonly property bool hasLyrics:
        !!Services.NeteaseWebLyricsService.hasLyrics
            || (root._preferLyricsMediaSource && root._hasStableLyricsCache())
    readonly property string displayPrimaryLyric: root.preferTranslatedLyrics
        ? (root.currentTranslatedLyric !== ""
            ? root.currentTranslatedLyric
            : (root.currentLyric !== "" ? root.currentLyric : ""))
        : (root.currentLyric !== ""
            ? root.currentLyric
            : (root.currentTranslatedLyric !== "" ? root.currentTranslatedLyric : ""))
    readonly property bool _compactOriginalIsInstrumental: root._isInstrumentalLyric(root._compactDisplayedLyric)
    readonly property string compactOriginalLyric: root._compactOriginalIsInstrumental ? "" : root._compactDisplayedLyric
    readonly property string compactOriginalLyricKey: root._compactOriginalIsInstrumental ? "" : root._compactDisplayedLyricKey
    readonly property string compactTranslatedLyric: root._compactOriginalIsInstrumental || root._isInstrumentalLyric(root._compactDisplayedTranslatedLyric) ? "" : root._compactDisplayedTranslatedLyric
    readonly property string compactTranslatedLyricKey: root._compactOriginalIsInstrumental || root._isInstrumentalLyric(root._compactDisplayedTranslatedLyric) ? "" : root._compactDisplayedTranslatedLyricKey
    // Primary compact line follows the translation preference and falls
    // back to the original line when no translated text is available.
    readonly property string compactPrimaryLyric: root.compactTranslatedLyric !== ""
        ? root.compactTranslatedLyric : root.compactOriginalLyric
    readonly property string compactPrimaryLyricKey: root.compactTranslatedLyric !== ""
        ? root.compactTranslatedLyricKey : root.compactOriginalLyricKey
    readonly property bool showCompactLyric:
        root.preferLyrics && (root.compactOriginalLyric !== "" || root.compactTranslatedLyric !== "")
    readonly property real progress:
        root.lengthMs > 0 ? Math.max(0, Math.min(1, root.positionMs / root.lengthMs)) : 0

    function _isInstrumentalLyric(text) {
        return text === "纯音乐，请欣赏" || text === "纯音乐，请欣赏。"
    }

    function _normalizedTrackTitle(value) {
        return value != null ? String(value).trim().toLowerCase().replace(/\s+/g, " ") : ""
    }

    function _normalizedArtistKey(value) {
        const normalized = value != null ? String(value).trim().toLowerCase().replace(/\s+/g, " ") : ""
        if (normalized === "")
            return ""

        const tokens = normalized
            .split(/\s*(?:,|，|\/|&|、|;|；| feat\.? | featuring )\s*/)
            .map(token => token.trim())
            .filter(token => token !== "")

        const unique = []
        for (let index = 0; index < tokens.length; index += 1) {
            const token = tokens[index]
            if (unique.indexOf(token) === -1)
                unique.push(token)
        }

        unique.sort()
        return unique.join(",")
    }

    function _normalizedTrackKey(title, artist) {
        const normalizedTitle = root._normalizedTrackTitle(title)
        if (normalizedTitle === "")
            return ""

        return [normalizedTitle, root._normalizedArtistKey(artist)].join("|")
    }

    function _trackKeysMatch(firstKey, secondKey) {
        if (firstKey === "" || secondKey === "")
            return false
        if (firstKey === secondKey)
            return true

        const firstParts = firstKey.split("|")
        const secondParts = secondKey.split("|")
        const firstTitle = firstParts.length > 0 ? firstParts[0] : ""
        const secondTitle = secondParts.length > 0 ? secondParts[0] : ""
        if (firstTitle === "" || secondTitle === "" || firstTitle !== secondTitle)
            return false

        const firstArtist = firstParts.length > 1 ? firstParts[1] : ""
        const secondArtist = secondParts.length > 1 ? secondParts[1] : ""
        return firstArtist === "" || secondArtist === ""
    }

    function _lyricKey(prefix, phase, index, text) {
        if (text === "")
            return ""

        return prefix + ":" + text
    }

    function _compactTrackDisplayState(prefix, phase, index, text) {
        if (text === "")
            return { text: "", key: "" }

        return {
            text: text,
            key: root._lyricKey(prefix, phase, index, text)
        }
    }

    function _selectedCompactTrackPrefix() {
        return root.preferTranslatedLyrics ? "translated" : "original"
    }

    function _setCompactDisplayedTrack(trackPrefix, state) {
        if (trackPrefix === "translated") {
            root._compactDisplayedTranslatedLyric = state.text
            root._compactDisplayedTranslatedLyricKey = state.key
            return
        }

        root._compactDisplayedTrack = state.text !== "" ? trackPrefix : ""
        root._compactDisplayedLyric = state.text
        root._compactDisplayedLyricKey = state.key
        root._compactDisplayedLyricsSessionKey = state.text !== "" ? root._lyricsSessionKey : ""
        root._compactDisplayedLyricsPlayerTrackKey = state.text !== "" ? root._playerTrackKey : ""
    }

    function _clearCompactDisplayedLyric() {
        root._compactDisplayedTrack = ""
        root._compactDisplayedLyric = ""
        root._compactDisplayedLyricKey = ""
        root._compactDisplayedTranslatedLyric = ""
        root._compactDisplayedTranslatedLyricKey = ""
        root._compactDisplayedLyricsSessionKey = ""
        root._compactDisplayedLyricsPlayerTrackKey = ""
    }

    function _clearStableLyrics() {
        root._stableCurrentLyric = ""
        root._stableNextLyric = ""
        root._stableCurrentTranslatedLyric = ""
        root._stableNextTranslatedLyric = ""
        root._clearCompactDisplayedLyric()
    }

    function _hasStableLyricsCache() {
        return root._stableCurrentLyric !== ""
            || root._stableNextLyric !== ""
            || root._stableCurrentTranslatedLyric !== ""
            || root._stableNextTranslatedLyric !== ""
    }

    function _resetLyricsLatch() {
        lyricsSourceTimer.stop()
        root._lyricsSourceLatched = false
        root._latchedLyricsSessionKey = ""
        root._latchedPlayerTrackKey = ""
        root._latchedSourceTrackKey = ""
        root._clearStableLyrics()
    }

    function _compactDisplayedState(trackPrefix) {
        if (trackPrefix === "translated") {
            return {
                text: root._compactDisplayedTranslatedLyric,
                key: root._compactDisplayedTranslatedLyricKey
            }
        }

        return {
            text: root._compactDisplayedLyric,
            key: root._compactDisplayedLyricKey
        }
    }

    function _updateCompactDisplayedTrack(trackPrefix) {
        const isTranslatedTrack = trackPrefix === "translated"
        const currentServiceValue = isTranslatedTrack ? Services.NeteaseWebLyricsService.currentTranslatedLyric : Services.NeteaseWebLyricsService.currentLyric
        const displayedState = root._compactDisplayedState(trackPrefix)
        // Both tracks share the stable-cache fallback: a transiently empty
        // service value (e.g. mid-refresh) must not drop the displayed line.
        const stableFallback = isTranslatedTrack ? root._stableCurrentTranslatedLyric : root._stableCurrentLyric

        let desiredState = root._compactTrackDisplayState(
            trackPrefix,
            "current",
            isTranslatedTrack ? Services.NeteaseWebLyricsService.currentTranslatedLyricIndex : Services.NeteaseWebLyricsService.currentLyricIndex,
            currentServiceValue === "" && stableFallback !== "" ? stableFallback : currentServiceValue
        )

        if (desiredState.text === "") {
            if (isTranslatedTrack) {
                desiredState = { text: "", key: "" }
            } else if (displayedState.text !== "") {
                desiredState = displayedState
            }
        }

        if (desiredState.text === displayedState.text && desiredState.key === displayedState.key)
            return

        root._setCompactDisplayedTrack(trackPrefix, desiredState)
    }

    function _updateCompactDisplayedLyric() {
        root._updateCompactDisplayedTrack("original")
        root._updateCompactDisplayedTrack("translated")
    }

    function _refreshLyricsSession() {
        const sessionKey = root._lyricsSessionKey
        const playerTrackKey = root._playerTrackKey
        const sourceTrackKey = root._lyricsMetadataKey
        const currentTrackMatchesLatched = root._trackKeysMatch(playerTrackKey, root._latchedPlayerTrackKey)
        const hasStableLyrics = root.hasLyrics || root._hasStableLyricsCache()
        const lyricsSessionChanged = sessionKey !== "" && root._latchedLyricsSessionKey !== ""
            && sessionKey !== root._latchedLyricsSessionKey
        const playerTrackChanged = playerTrackKey !== "" && root._latchedPlayerTrackKey !== ""
            && !root._trackKeysMatch(playerTrackKey, root._latchedPlayerTrackKey)
        // The lyric source's own track identity is authoritative: when it
        // changes, the song switched even if the player's metadata key lags
        // behind and would otherwise mask the session churn.
        const sourceTrackChanged = sourceTrackKey !== "" && root._latchedSourceTrackKey !== ""
            && !root._trackKeysMatch(sourceTrackKey, root._latchedSourceTrackKey)
        // An id-keyed session change is an authoritative track switch even
        // if the player's metadata key lags behind the web source.
        const sessionIdChanged = lyricsSessionChanged
            && sessionKey.indexOf("id:") === 0
            && root._latchedLyricsSessionKey.indexOf("id:") === 0
        const shouldIgnoreSessionKeyChurn = lyricsSessionChanged && !sessionIdChanged
            && currentTrackMatchesLatched
            && hasStableLyrics && root._lyricsSignalActive

        if ((lyricsSessionChanged && !shouldIgnoreSessionKeyChurn) || playerTrackChanged || sourceTrackChanged)
            root._resetLyricsLatch()

        if (sessionKey !== "")
            root._latchedLyricsSessionKey = sessionKey
        if (playerTrackKey !== "")
            root._latchedPlayerTrackKey = playerTrackKey
        if (sourceTrackKey !== "")
            root._latchedSourceTrackKey = sourceTrackKey

        // No-lyric fallback is the bare title: never join the artist with
        // " · " on the primary row.
        var fallbackText = Services.NeteaseWebLyricsService.title
        
        // For primary/original lyrics: show fallback (title/artist) when no actual lyric
        if (Services.NeteaseWebLyricsService.currentLyric !== "")
            root._stableCurrentLyric = Services.NeteaseWebLyricsService.currentLyric
        else
            // Fallback to title/artist when no current lyric (e.g., before first timestamp)
            root._stableCurrentLyric = fallbackText
            
        if (Services.NeteaseWebLyricsService.nextLyric !== "")
            root._stableNextLyric = Services.NeteaseWebLyricsService.nextLyric
        else
            // Fallback to title/artist when no next lyric
            root._stableNextLyric = fallbackText
            
        // For translated/secondary lyrics: keep empty when no actual translated lyric
        // (don't use fallback, so secondary line stays blank)
        if (Services.NeteaseWebLyricsService.currentTranslatedLyric !== "")
            root._stableCurrentTranslatedLyric = Services.NeteaseWebLyricsService.currentTranslatedLyric
        if (Services.NeteaseWebLyricsService.nextTranslatedLyric !== "")
            root._stableNextTranslatedLyric = Services.NeteaseWebLyricsService.nextTranslatedLyric

        if (!root._lyricsSignalActive && !(currentTrackMatchesLatched && hasStableLyrics)) {
            root._updateCompactDisplayedLyric()
            return
        }

        root._lyricsSourceLatched = true
        lyricsSourceTimer.restart()
        root._updateCompactDisplayedLyric()
    }

    function playPause() {
        Services.MediaService.playPause()
    }

    function previous() {
        Services.MediaService.previous()
    }

    function next() {
        Services.MediaService.next()
    }

    function seekToProgress(progressValue) {
        Services.MediaService.setProgress(progressValue)
    }

    Component.onCompleted: {
        root._refreshLyricsSession()
        root._updateCompactDisplayedLyric()
    }

    // Coalesce refreshes onto the next event-loop turn: a track switch
    // arrives as a burst of property writes (songId, title, artist, lyric
    // window), and evaluating mid-batch would refill the stable caches from
    // half-updated values and resurrect the previous song's lines.
    function _scheduleLyricsRefresh() {
        lyricsRefreshCoalescer.restart()
    }

    Timer {
        id: lyricsRefreshCoalescer

        interval: 0
        repeat: false
        onTriggered: root._refreshLyricsSession()
    }

    onCurrentLyricChanged: root._scheduleLyricsRefresh()
    onNextLyricChanged: root._scheduleLyricsRefresh()
    onCurrentTranslatedLyricChanged: root._scheduleLyricsRefresh()
    onNextTranslatedLyricChanged: root._scheduleLyricsRefresh()
    onHasLyricsChanged: root._scheduleLyricsRefresh()

    Timer {
        id: lyricsSourceTimer

        interval: 15000
        repeat: false
        onTriggered: {
            if (root._lyricsSignalActive || (root._playerTrackKey !== ""
                    && root._latchedPlayerTrackKey !== ""
                    && root._trackKeysMatch(root._playerTrackKey, root._latchedPlayerTrackKey)
                    && root._hasStableLyricsCache())) {
                lyricsSourceTimer.restart()
                return
            }

            root._resetLyricsLatch()
        }
    }

    Connections {
        target: Services.MediaService

        function onTitleChanged() { root._scheduleLyricsRefresh() }
        function onArtistChanged() { root._scheduleLyricsRefresh() }
        function onPlaybackStateChanged() { root._scheduleLyricsRefresh() }
        function onHasPlayerChanged() { root._scheduleLyricsRefresh() }
    }

    Connections {
        target: Services.NeteaseWebLyricsService

        function onSongIdChanged() { root._scheduleLyricsRefresh() }
        function onTitleChanged() { root._scheduleLyricsRefresh() }
        function onArtistChanged() { root._scheduleLyricsRefresh() }
        function onActiveChanged() { root._scheduleLyricsRefresh() }
        function onHasLyricsChanged() { root._scheduleLyricsRefresh() }
        function onRawLyricChanged() { root._scheduleLyricsRefresh() }
        function onTranslatedLyricChanged() { root._scheduleLyricsRefresh() }
        function onCurrentLyricChanged() { root._scheduleLyricsRefresh() }
        function onNextLyricChanged() { root._scheduleLyricsRefresh() }
        function onCurrentTranslatedLyricChanged() { root._scheduleLyricsRefresh() }
        function onNextTranslatedLyricChanged() { root._scheduleLyricsRefresh() }
        function onPlaybackStateChanged() { root._scheduleLyricsRefresh() }
    }
}
