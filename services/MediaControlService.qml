pragma Singleton

import Quickshell
import QtQuick
import qs.config
import qs.services

// Adapts media state into the compact and expanded control surfaces used by the bar.
Singleton {
    id: root

    readonly property bool _debugLyricDisplay:
        (Quickshell.env("DYMICSHELL_MEDIA_LYRIC_DEBUG") || "").trim() === "1"
    readonly property bool _lyricsSignalActive:
        SettingsService.data.mediaControl.showLyrics
            && SettingsService.data.mediaControl.preferLyrics
            && (NeteaseWebLyricsService.active
                || NeteaseWebLyricsService.hasLyrics
                || NeteaseWebLyricsService.currentLyric !== ""
                || NeteaseWebLyricsService.nextLyric !== ""
                || NeteaseWebLyricsService.currentTranslatedLyric !== ""
                || NeteaseWebLyricsService.nextTranslatedLyric !== ""
                || NeteaseWebLyricsService.rawLyric !== ""
                || NeteaseWebLyricsService.translatedLyric !== "")
    readonly property string _lyricsMetadataKey:
        NeteaseWebLyricsService.title !== "" && NeteaseWebLyricsService.artist !== ""
            ? [NeteaseWebLyricsService.title, NeteaseWebLyricsService.artist].join("|")
            : ""
    readonly property string _lyricsSessionKey:
        NeteaseWebLyricsService.songId !== ""
            ? "id:" + NeteaseWebLyricsService.songId
            : (root._lyricsMetadataKey !== "" ? "meta:" + root._lyricsMetadataKey : "")
    readonly property bool preferTranslatedLyrics:
        SettingsService.data.mediaControl.lyricsPrimarySource === "translated"
    readonly property string _playerTrackKey:
        MediaService.hasPlayer
            ? [MediaService.title || "", MediaService.artist || ""].join("|")
            : ""
    property bool _lyricsSourceLatched: false
    property string _latchedLyricsSessionKey: ""
    property string _latchedPlayerTrackKey: ""
    property string _stableCurrentLyric: ""
    property string _stableNextLyric: ""
    property string _stableCurrentTranslatedLyric: ""
    property string _stableNextTranslatedLyric: ""
    property string _compactDisplayedLyric: ""
    property string _compactDisplayedLyricKey: ""
    property string _compactDisplayedTrack: ""
    property string _compactDisplayedLyricsSessionKey: ""
    property string _compactDisplayedLyricsPlayerTrackKey: ""
    readonly property bool _freezeLyricsOnPause:
        root._preferLyricsMediaSource
            && MediaService.hasPlayer
            && MediaService.playbackState === "paused"
            && root._hasStableLyricsCache()
    readonly property bool _preferLyricsMediaSource:
        root._lyricsSourceLatched
    readonly property var _media: root._mediaOverride !== null ? root._mediaOverride : ({
        hasPlayer: MediaService.hasPlayer || NeteaseWebLyricsService.active || root._preferLyricsMediaSource,
        title: root._preferLyricsMediaSource
            ? (NeteaseWebLyricsService.title !== ""
                ? NeteaseWebLyricsService.title
                : (MediaService.hasPlayer ? MediaService.title : ""))
            : (MediaService.hasPlayer ? MediaService.title : NeteaseWebLyricsService.title),
        artist: root._preferLyricsMediaSource
            ? (NeteaseWebLyricsService.artist !== ""
                ? NeteaseWebLyricsService.artist
                : (MediaService.hasPlayer ? MediaService.artist : ""))
            : (MediaService.hasPlayer ? MediaService.artist : NeteaseWebLyricsService.artist),
        artUrl: MediaService.hasPlayer ? MediaService.artUrl : "",
        playerName: MediaService.hasPlayer ? MediaService.playerName : "",
        playbackState: root._preferLyricsMediaSource
            ? ((MediaService.hasPlayer && MediaService.playbackState !== "playing")
                ? MediaService.playbackState
                : ((NeteaseWebLyricsService.playbackState !== "stopped" || !MediaService.hasPlayer)
                ? NeteaseWebLyricsService.playbackState
                : MediaService.playbackState))
            : (MediaService.hasPlayer ? MediaService.playbackState : NeteaseWebLyricsService.playbackState),
        positionMs: root._preferLyricsMediaSource
            ? ((MediaService.hasPlayer && MediaService.playbackState !== "playing")
                ? MediaService.positionMs
                : ((NeteaseWebLyricsService.durationMs > 0 || NeteaseWebLyricsService.positionMs > 0 || !MediaService.hasPlayer)
                ? NeteaseWebLyricsService.positionMs
                : MediaService.positionMs))
            : (MediaService.hasPlayer ? MediaService.positionMs : NeteaseWebLyricsService.positionMs),
        lengthMs: root._preferLyricsMediaSource
            ? ((MediaService.hasPlayer && MediaService.playbackState !== "playing")
                ? MediaService.lengthMs
                : ((NeteaseWebLyricsService.durationMs > 0 || !MediaService.hasPlayer)
                ? NeteaseWebLyricsService.durationMs
                : MediaService.lengthMs))
            : (MediaService.hasPlayer ? MediaService.lengthMs : NeteaseWebLyricsService.durationMs),
        canGoPrevious: MediaService.hasPlayer ? MediaService.canGoPrevious : false,
        canTogglePlayback: MediaService.hasPlayer ? MediaService.canTogglePlayback : false,
        canGoNext: MediaService.hasPlayer ? MediaService.canGoNext : false,
        canSeek: MediaService.hasPlayer ? MediaService.canSeek : false
    })

    readonly property bool hasMedia: !!root._media.hasPlayer
    readonly property string title: root._media.title || ""
    readonly property string artist: root._media.artist || ""
    readonly property string artUrl: root._media.artUrl || ""
    readonly property string playerName: root._media.playerName || ""
    readonly property string playbackState: root._media.playbackState || "stopped"
    readonly property int positionMs: Math.max(0, root._media.positionMs || 0)
    readonly property int lengthMs: Math.max(0, root._media.lengthMs || 0)
    readonly property real progress:
        root.lengthMs > 0 ? Math.max(0, Math.min(1, root.positionMs / root.lengthMs)) : 0
    readonly property string positionLabel: root._formatMs(root.positionMs)
    readonly property string durationLabel: root._formatMs(root.lengthMs)
    readonly property var visualizerBars:
        root._visualizerOverride !== null
            ? (root._visualizerOverride.bars || [])
            : (CavaService.healthy ? CavaService.bars : [])
    readonly property bool visualizerHealthy:
        root._visualizerOverride !== null
            ? !!root._visualizerOverride.healthy
            : CavaService.healthy
    readonly property bool canGoPrevious: !!root._media.canGoPrevious
    readonly property bool canTogglePlayback: !!root._media.canTogglePlayback
    readonly property bool canGoNext: !!root._media.canGoNext
    readonly property bool canSeek: !!root._media.canSeek
    readonly property string currentLyric:
        root._freezeLyricsOnPause
            ? root._stableCurrentLyric
            : (NeteaseWebLyricsService.currentLyric !== ""
            ? NeteaseWebLyricsService.currentLyric
            : ((NeteaseWebLyricsService.currentLyric === ""
                && NeteaseWebLyricsService.nextLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableCurrentLyric
                : ""))
    readonly property string nextLyric:
        root._freezeLyricsOnPause
            ? root._stableNextLyric
            : (NeteaseWebLyricsService.nextLyric !== ""
            ? NeteaseWebLyricsService.nextLyric
            : ((NeteaseWebLyricsService.currentLyric === ""
                && NeteaseWebLyricsService.nextLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableNextLyric
                : ""))
    readonly property string currentTranslatedLyric:
        root._freezeLyricsOnPause
            ? root._stableCurrentTranslatedLyric
            : (NeteaseWebLyricsService.currentTranslatedLyric !== ""
            ? NeteaseWebLyricsService.currentTranslatedLyric
            : ((NeteaseWebLyricsService.currentTranslatedLyric === ""
                && NeteaseWebLyricsService.nextTranslatedLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableCurrentTranslatedLyric
                : ""))
    readonly property string nextTranslatedLyric:
        root._freezeLyricsOnPause
            ? root._stableNextTranslatedLyric
            : (NeteaseWebLyricsService.nextTranslatedLyric !== ""
            ? NeteaseWebLyricsService.nextTranslatedLyric
            : ((NeteaseWebLyricsService.currentTranslatedLyric === ""
                && NeteaseWebLyricsService.nextTranslatedLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableNextTranslatedLyric
                : ""))
    readonly property bool hasLyrics:
        !!NeteaseWebLyricsService.hasLyrics
            || (root._preferLyricsMediaSource
                && (root._stableCurrentLyric !== ""
                    || root._stableNextLyric !== ""
                    || root._stableCurrentTranslatedLyric !== ""
                    || root._stableNextTranslatedLyric !== ""))
    readonly property string displayPrimaryLyric: root.preferTranslatedLyrics
        ? (root.currentTranslatedLyric !== ""
            ? root.currentTranslatedLyric
            : (root.currentLyric !== "" ? root.currentLyric : ""))
        : (root.currentLyric !== ""
            ? root.currentLyric
            : (root.currentTranslatedLyric !== "" ? root.currentTranslatedLyric : ""))
    readonly property string compactPrimaryLyric: root._compactDisplayedLyric
    readonly property string displaySecondaryLyric: root.preferTranslatedLyrics
        ? (root.currentLyric !== "" ? root.currentLyric : "")
        : (root.currentTranslatedLyric !== "" ? root.currentTranslatedLyric : "")
    readonly property string displayPrimaryLyricKey: root._displayPrimaryLyricKey()
    readonly property string compactPrimaryLyricKey: root._compactDisplayedLyricKey
    readonly property string displaySecondaryLyricKey: root._displaySecondaryLyricKey()

    property string announcementState: "idle"
    property bool panelOpen: false
    property int eventRevision: 0
    property var _mediaOverride: null
    property var _visualizerOverride: null
    property string _lastAnnouncementSignature: ""
    property string _lastPlaybackState: "stopped"

    function _lyricKey(prefix, phase, index, text) {
        if (text === "")
            return ""

        return prefix + ":" + text
    }

    function _firstNonEmpty(candidates) {
        for (let i = 0; i < candidates.length; i++) {
            if (candidates[i] !== "")
                return candidates[i]
        }

        return ""
    }

    function _selectedCompactTrackPrefix() {
        return root.preferTranslatedLyrics ? "translated" : "original"
    }

    function _compactTrackDisplayState(prefix, phase, index, text) {
        if (text === "")
            return { text: "", key: "" }

        return {
            text: text,
            // Use text-only keys for compact lyric display so repeated lyric updates
            // do not trigger animation when visible text remains unchanged.
            key: root._lyricKey(prefix, phase, 0, text)
        }
    }

    function _stableCompactTrackDisplayState(prefix, phase, text) {
        if (text === "")
            return { text: "", key: "" }

        return {
            text: text,
            key: root._lyricKey(prefix, phase, 0, text)
        }
    }

    function _setCompactDisplayedLyric(state, trackPrefix) {
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
        root._compactDisplayedLyricsSessionKey = ""
        root._compactDisplayedLyricsPlayerTrackKey = ""
    }

    function _updateCompactDisplayedLyric() {
        const trackPrefix = root._selectedCompactTrackPrefix()
        const currentState = root.preferTranslatedLyrics
            ? root._compactTrackDisplayState(trackPrefix, "current", NeteaseWebLyricsService.currentTranslatedLyricIndex, root.currentTranslatedLyric)
            : root._compactTrackDisplayState(trackPrefix, "current", NeteaseWebLyricsService.currentLyricIndex, root.currentLyric)
        const stableCurrentState = root.preferTranslatedLyrics
            ? root._stableCompactTrackDisplayState(trackPrefix, "current", root._stableCurrentTranslatedLyric)
            : root._stableCompactTrackDisplayState(trackPrefix, "current", root._stableCurrentLyric)
        const nextState = root.preferTranslatedLyrics
            ? root._compactTrackDisplayState(trackPrefix, "next", NeteaseWebLyricsService.nextTranslatedLyricIndex, root.nextTranslatedLyric)
            : root._compactTrackDisplayState(trackPrefix, "next", NeteaseWebLyricsService.nextLyricIndex, root.nextLyric)
        const stableNextState = root.preferTranslatedLyrics
            ? root._stableCompactTrackDisplayState(trackPrefix, "next", root._stableNextTranslatedLyric)
            : root._stableCompactTrackDisplayState(trackPrefix, "next", root._stableNextLyric)
        let desiredState = { text: "", key: "" }

        if (!SettingsService.data.mediaControl.showLyrics || !SettingsService.data.mediaControl.preferLyrics) {
            if (root._compactDisplayedLyric !== "")
                root._clearCompactDisplayedLyric()
            return
        }

        if (currentState.text !== "") {
            desiredState = currentState
        } else if (stableCurrentState.text !== "") {
            desiredState = stableCurrentState
        } else if (root._compactDisplayedTrack === trackPrefix && root._compactDisplayedLyric !== "") {
            desiredState = {
                text: root._compactDisplayedLyric,
                key: root._compactDisplayedLyricKey
            }
        } else if ((root._compactDisplayedLyric !== "" || stableCurrentState.text !== "") && nextState.text !== "") {
            desiredState = nextState
        } else if ((root._compactDisplayedLyric !== "" || stableCurrentState.text !== "") && stableNextState.text !== "") {
            desiredState = stableNextState
        }

        if (desiredState.text === root._compactDisplayedLyric && desiredState.key === root._compactDisplayedLyricKey)
            return

        if (desiredState.text === "") {
            root._clearCompactDisplayedLyric()
            return
        }

        root._setCompactDisplayedLyric(desiredState, trackPrefix)
    }

    function _displayPrimaryLyricKey() {
        if (root.preferTranslatedLyrics) {
            if (root.currentTranslatedLyric !== "")
                return root._lyricKey("translated", "current", NeteaseWebLyricsService.currentTranslatedLyricIndex, root.currentTranslatedLyric)
            if (root.currentLyric !== "")
                return root._lyricKey("original", "current", NeteaseWebLyricsService.currentLyricIndex, root.currentLyric)
            return ""
        }

        if (root.currentLyric !== "")
            return root._lyricKey("original", "current", NeteaseWebLyricsService.currentLyricIndex, root.currentLyric)
        if (root.currentTranslatedLyric !== "")
            return root._lyricKey("translated", "current", NeteaseWebLyricsService.currentTranslatedLyricIndex, root.currentTranslatedLyric)
        return ""
    }

    function _displaySecondaryLyricKey() {
        if (root.preferTranslatedLyrics) {
            if (root.currentLyric !== "")
                return root._lyricKey("original", "current", NeteaseWebLyricsService.currentLyricIndex, root.currentLyric)
            return ""
        }

        if (root.currentTranslatedLyric !== "")
            return root._lyricKey("translated", "current", NeteaseWebLyricsService.currentTranslatedLyricIndex, root.currentTranslatedLyric)
        return ""
    }

    function _logLyricSelection(reason) {
        if (!root._debugLyricDisplay)
            return

        console.log("[DymicShell:MediaControlLyric]", JSON.stringify({
            reason: reason,
            preferTranslatedLyrics: root.preferTranslatedLyrics,
            displayPrimaryLyric: root.displayPrimaryLyric,
            displayPrimaryLyricKey: root.displayPrimaryLyricKey,
            compactPrimaryLyric: root.compactPrimaryLyric,
            compactPrimaryLyricKey: root.compactPrimaryLyricKey,
            displaySecondaryLyric: root.displaySecondaryLyric,
            currentLyric: root.currentLyric,
            nextLyric: root.nextLyric,
            currentTranslatedLyric: root.currentTranslatedLyric,
            nextTranslatedLyric: root.nextTranslatedLyric,
            stableCurrentLyric: root._stableCurrentLyric,
            stableNextLyric: root._stableNextLyric,
            stableCurrentTranslatedLyric: root._stableCurrentTranslatedLyric,
            stableNextTranslatedLyric: root._stableNextTranslatedLyric,
            compactDisplayedTrack: root._compactDisplayedTrack,
            lyricsSourceLatched: root._lyricsSourceLatched,
            freezeLyricsOnPause: root._freezeLyricsOnPause
        }))
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
        _lyricsSourceTimer.stop()
        root._lyricsSourceLatched = false
        root._latchedLyricsSessionKey = ""
        root._latchedPlayerTrackKey = ""
        root._clearStableLyrics()
    }

    function _refreshLyricsSession() {
        if (!SettingsService.data.mediaControl.showLyrics || !SettingsService.data.mediaControl.preferLyrics) {
            root._resetLyricsLatch()
            return
        }

        const sessionKey = root._lyricsSessionKey
        const playerTrackKey = root._playerTrackKey
        const currentTrackMatchesLatched = playerTrackKey !== ""
            && root._latchedPlayerTrackKey !== ""
            && playerTrackKey === root._latchedPlayerTrackKey
        const hasStableLyrics = root.hasLyrics || root._hasStableLyricsCache()
        const lyricsSessionChanged = sessionKey !== ""
            && root._latchedLyricsSessionKey !== ""
            && sessionKey !== root._latchedLyricsSessionKey
        const playerTrackChanged = playerTrackKey !== ""
            && root._latchedPlayerTrackKey !== ""
            && playerTrackKey !== root._latchedPlayerTrackKey
        const shouldIgnoreSessionKeyChurn = lyricsSessionChanged
            && currentTrackMatchesLatched
            && hasStableLyrics
            && root._lyricsSignalActive

        if ((lyricsSessionChanged && !shouldIgnoreSessionKeyChurn) || playerTrackChanged)
            root._resetLyricsLatch()

        if (sessionKey !== "")
            root._latchedLyricsSessionKey = sessionKey
        if (playerTrackKey !== "")
            root._latchedPlayerTrackKey = playerTrackKey

        if (!root._freezeLyricsOnPause) {
            if (NeteaseWebLyricsService.currentLyric !== "")
                root._stableCurrentLyric = NeteaseWebLyricsService.currentLyric
            if (NeteaseWebLyricsService.nextLyric !== "")
                root._stableNextLyric = NeteaseWebLyricsService.nextLyric
            if (NeteaseWebLyricsService.currentTranslatedLyric !== "")
                root._stableCurrentTranslatedLyric = NeteaseWebLyricsService.currentTranslatedLyric
            if (NeteaseWebLyricsService.nextTranslatedLyric !== "")
                root._stableNextTranslatedLyric = NeteaseWebLyricsService.nextTranslatedLyric
        }

        if (!root._lyricsSignalActive && !(currentTrackMatchesLatched && hasStableLyrics)) {
            root._updateCompactDisplayedLyric()
            return
        }

        root._lyricsSourceLatched = true
        _lyricsSourceTimer.restart()
        root._updateCompactDisplayedLyric()
    }

    function togglePanel() {
        root.panelOpen = !root.panelOpen
    }

    function openPanel() {
        root.panelOpen = true
    }

    function closePanel() {
        root.panelOpen = false
    }

    function playPause() {
        MediaService.playPause()
    }

    function previous() {
        MediaService.previous()
    }

    function next() {
        MediaService.next()
    }

    function seekToProgress(progress) {
        MediaService.setProgress(progress)
    }

    function acknowledgeAnnouncement() {
        _enterTimer.stop()
        _dismissTimer.stop()
        _exitTimer.stop()
        root.announcementState = "idle"
    }

    function _setMediaOverride(state) {
        root._mediaOverride = state
        root._handleMediaChanged()
    }

    function _setVisualizerOverride(state) {
        root._visualizerOverride = state
    }

    function _signatureForMedia(media) {
        if (!media || !media.hasPlayer)
            return ""

        return [
            media.playerName || "",
            media.title || "",
            media.artist || "",
            media.artUrl || ""
        ].join("|")
    }

    function _formatMs(milliseconds) {
        const totalSeconds = Math.max(0, Math.round((milliseconds || 0) / 1000))
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60

        if (hours > 0)
            return String(hours).padStart(2, "0") + ":"
                + String(minutes).padStart(2, "0") + ":"
                + String(seconds).padStart(2, "0")

        return String(minutes).padStart(2, "0") + ":"
            + String(seconds).padStart(2, "0")
    }

    on_LyricsSignalActiveChanged: root._refreshLyricsSession()
    on_LyricsSessionKeyChanged: root._refreshLyricsSession()
    on_PlayerTrackKeyChanged: root._refreshLyricsSession()

    function _handleMediaChanged() {
        const signature = root._signatureForMedia(root._media)
        const playbackState = root.playbackState

        if (!root.hasMedia) {
            root._lastAnnouncementSignature = ""
            root._lastPlaybackState = "stopped"
            root.announcementState = "idle"
            return
        }

        const signatureChanged = signature !== "" && signature !== root._lastAnnouncementSignature
        const playbackChanged = playbackState !== root._lastPlaybackState

        root._lastAnnouncementSignature = signature
        root._lastPlaybackState = playbackState

        if (!signatureChanged && !playbackChanged)
            return

        root.eventRevision += 1

        if (!SettingsService.data.mediaControl.announcementEnabled)
            return

        _enterTimer.stop()
        _dismissTimer.stop()
        _exitTimer.stop()
        root.announcementState = "announce"
        _enterTimer.start()
    }

    Component.onCompleted: {
        root._refreshLyricsSession()
        root._lastAnnouncementSignature = root._signatureForMedia(root._media)
        root._lastPlaybackState = root.playbackState
        root._logLyricSelection("component-completed")
    }

    onDisplayPrimaryLyricChanged: root._logLyricSelection("display-primary-changed")
    onCompactPrimaryLyricChanged: root._logLyricSelection("compact-primary-changed")
    onDisplayPrimaryLyricKeyChanged: root._logLyricSelection("display-primary-key-changed")
    onCompactPrimaryLyricKeyChanged: root._logLyricSelection("compact-primary-key-changed")
    onPreferTranslatedLyricsChanged: root._updateCompactDisplayedLyric()
    onCurrentLyricChanged: root._updateCompactDisplayedLyric()
    onNextLyricChanged: root._updateCompactDisplayedLyric()
    onCurrentTranslatedLyricChanged: root._updateCompactDisplayedLyric()
    onNextTranslatedLyricChanged: root._updateCompactDisplayedLyric()
    onHasLyricsChanged: root._updateCompactDisplayedLyric()

    Timer {
        id: _lyricsSourceTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (root._lyricsSignalActive || (root._playerTrackKey !== ""
                    && root._latchedPlayerTrackKey !== ""
                    && root._playerTrackKey === root._latchedPlayerTrackKey
                    && root._hasStableLyricsCache())) {
                _lyricsSourceTimer.restart()
                return
            }

            root._resetLyricsLatch()
        }
    }

    Timer {
        id: _enterTimer
        interval: Math.max(80, Math.round(Theme.anim.highlightDuration / 2))
        repeat: false
        onTriggered: {
            root.announcementState = "hold"
            _dismissTimer.restart()
        }
    }

    Timer {
        id: _dismissTimer
        interval: SettingsService.data.mediaControl.announcementDuration
        repeat: false
        onTriggered: {
            root.announcementState = "dismiss"
            _exitTimer.restart()
        }
    }

    Timer {
        id: _exitTimer
        interval: Theme.anim.exitDuration
        repeat: false
        onTriggered: root.announcementState = "idle"
    }

    Connections {
        target: MediaService
        function onMediaChanged() {
            root._handleMediaChanged()
        }
        function onTitleChanged() {
            root._refreshLyricsSession()
        }
        function onArtistChanged() {
            root._refreshLyricsSession()
        }
        function onPlaybackStateChanged() {
            root._refreshLyricsSession()
        }
        function onHasPlayerChanged() {
            root._refreshLyricsSession()
        }
    }

    Connections {
        target: SettingsService
        function onSettingsReloaded() {
            root._refreshLyricsSession()
            if (!SettingsService.data.mediaControl.announcementEnabled)
                root.acknowledgeAnnouncement()
        }
    }

    Connections {
        target: NeteaseWebLyricsService
        function onSongIdChanged() { root._refreshLyricsSession() }
        function onTitleChanged() { root._refreshLyricsSession() }
        function onArtistChanged() { root._refreshLyricsSession() }
        function onActiveChanged() { root._refreshLyricsSession() }
        function onHasLyricsChanged() { root._refreshLyricsSession() }
        function onRawLyricChanged() { root._refreshLyricsSession() }
        function onTranslatedLyricChanged() { root._refreshLyricsSession() }
        function onCurrentLyricChanged() { root._refreshLyricsSession() }
        function onNextLyricChanged() { root._refreshLyricsSession() }
        function onCurrentTranslatedLyricChanged() { root._refreshLyricsSession() }
        function onNextTranslatedLyricChanged() { root._refreshLyricsSession() }
        function onPlaybackStateChanged() { root._refreshLyricsSession() }
    }
}
