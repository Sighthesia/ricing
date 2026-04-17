pragma Singleton

import Quickshell
import QtQuick
import qs.config
import qs.services

// Adapts media state into the compact and expanded control surfaces used by the bar.
Singleton {
    id: root

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
    readonly property string _lyricsSessionKey:
        NeteaseWebLyricsService.songId !== ""
            ? NeteaseWebLyricsService.songId
            : [NeteaseWebLyricsService.title || "", NeteaseWebLyricsService.artist || ""].join("|")
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
            ? ((NeteaseWebLyricsService.playbackState !== "stopped" || !MediaService.hasPlayer)
                ? NeteaseWebLyricsService.playbackState
                : MediaService.playbackState)
            : (MediaService.hasPlayer ? MediaService.playbackState : NeteaseWebLyricsService.playbackState),
        positionMs: root._preferLyricsMediaSource
            ? ((NeteaseWebLyricsService.durationMs > 0 || NeteaseWebLyricsService.positionMs > 0 || !MediaService.hasPlayer)
                ? NeteaseWebLyricsService.positionMs
                : MediaService.positionMs)
            : (MediaService.hasPlayer ? MediaService.positionMs : NeteaseWebLyricsService.positionMs),
        lengthMs: root._preferLyricsMediaSource
            ? ((NeteaseWebLyricsService.durationMs > 0 || !MediaService.hasPlayer)
                ? NeteaseWebLyricsService.durationMs
                : MediaService.lengthMs)
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
        NeteaseWebLyricsService.currentLyric !== ""
            ? NeteaseWebLyricsService.currentLyric
            : ((NeteaseWebLyricsService.currentLyric === ""
                && NeteaseWebLyricsService.nextLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableCurrentLyric
                : "")
    readonly property string nextLyric:
        NeteaseWebLyricsService.nextLyric !== ""
            ? NeteaseWebLyricsService.nextLyric
            : ((NeteaseWebLyricsService.currentLyric === ""
                && NeteaseWebLyricsService.nextLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableNextLyric
                : "")
    readonly property string currentTranslatedLyric:
        NeteaseWebLyricsService.currentTranslatedLyric !== ""
            ? NeteaseWebLyricsService.currentTranslatedLyric
            : ((NeteaseWebLyricsService.currentTranslatedLyric === ""
                && NeteaseWebLyricsService.nextTranslatedLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableCurrentTranslatedLyric
                : "")
    readonly property string nextTranslatedLyric:
        NeteaseWebLyricsService.nextTranslatedLyric !== ""
            ? NeteaseWebLyricsService.nextTranslatedLyric
            : ((NeteaseWebLyricsService.currentTranslatedLyric === ""
                && NeteaseWebLyricsService.nextTranslatedLyric === ""
                && root._preferLyricsMediaSource)
                ? root._stableNextTranslatedLyric
                : "")
    readonly property bool hasLyrics:
        !!NeteaseWebLyricsService.hasLyrics
            || (root._preferLyricsMediaSource
                && (root._stableCurrentLyric !== ""
                    || root._stableNextLyric !== ""
                    || root._stableCurrentTranslatedLyric !== ""
                    || root._stableNextTranslatedLyric !== ""))

    property string announcementState: "idle"
    property bool panelOpen: false
    property int eventRevision: 0
    property var _mediaOverride: null
    property var _visualizerOverride: null
    property string _lastAnnouncementSignature: ""
    property string _lastPlaybackState: "stopped"

    function _clearStableLyrics() {
        root._stableCurrentLyric = ""
        root._stableNextLyric = ""
        root._stableCurrentTranslatedLyric = ""
        root._stableNextTranslatedLyric = ""
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
        const lyricsSessionChanged = sessionKey !== ""
            && root._latchedLyricsSessionKey !== ""
            && sessionKey !== root._latchedLyricsSessionKey
        const playerTrackChanged = playerTrackKey !== ""
            && root._latchedPlayerTrackKey !== ""
            && playerTrackKey !== root._latchedPlayerTrackKey

        if (lyricsSessionChanged || playerTrackChanged)
            root._resetLyricsLatch()

        if (sessionKey !== "")
            root._latchedLyricsSessionKey = sessionKey
        if (playerTrackKey !== "")
            root._latchedPlayerTrackKey = playerTrackKey

        if (NeteaseWebLyricsService.currentLyric !== "")
            root._stableCurrentLyric = NeteaseWebLyricsService.currentLyric
        if (NeteaseWebLyricsService.nextLyric !== "")
            root._stableNextLyric = NeteaseWebLyricsService.nextLyric
        if (NeteaseWebLyricsService.currentTranslatedLyric !== "")
            root._stableCurrentTranslatedLyric = NeteaseWebLyricsService.currentTranslatedLyric
        if (NeteaseWebLyricsService.nextTranslatedLyric !== "")
            root._stableNextTranslatedLyric = NeteaseWebLyricsService.nextTranslatedLyric

        if (!root._lyricsSignalActive)
            return

        root._lyricsSourceLatched = true
        _lyricsSourceTimer.restart()
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
    }

    Timer {
        id: _lyricsSourceTimer
        interval: 2500
        repeat: false
        onTriggered: root._resetLyricsLatch()
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
