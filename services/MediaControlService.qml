pragma Singleton

import Quickshell
import QtQuick
import qs.config
import qs.services

// Adapts media state into the compact and expanded control surfaces used by the bar.
Singleton {
    id: root

    readonly property var _media: root._mediaOverride !== null ? root._mediaOverride : ({
        hasPlayer: MediaService.hasPlayer,
        title: MediaService.title,
        artist: MediaService.artist,
        artUrl: MediaService.artUrl,
        playerName: MediaService.playerName,
        playbackState: MediaService.playbackState,
        positionMs: MediaService.positionMs,
        lengthMs: MediaService.lengthMs,
        canGoPrevious: MediaService.canGoPrevious,
        canTogglePlayback: MediaService.canTogglePlayback,
        canGoNext: MediaService.canGoNext,
        canSeek: MediaService.canSeek
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

    property string announcementState: "idle"
    property bool panelOpen: false
    property int eventRevision: 0
    property var _mediaOverride: null
    property var _visualizerOverride: null
    property string _lastAnnouncementSignature: ""
    property string _lastPlaybackState: "stopped"

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
        root._lastAnnouncementSignature = root._signatureForMedia(root._media)
        root._lastPlaybackState = root.playbackState
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
            if (!SettingsService.data.mediaControl.announcementEnabled)
                root.acknowledgeAnnouncement()
        }
    }
}
