pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Normalizes active MPRIS player state into one widget-friendly media source.
Singleton {
    id: root

    property int _positionTick: 0
    property string artUrl: ""
    property string _lastArtKey: ""
    property string _lastArtPlayerKey: ""
    property bool _artRecoveryPending: false
    property int _artRecoveryStartedAt: 0

    readonly property var activePlayer: {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    readonly property bool hasPlayer: activePlayer !== null
    readonly property string playerName:
        hasPlayer ? (activePlayer.identity || activePlayer.desktopEntry || "") : ""
    readonly property string desktopEntry:
        hasPlayer ? (activePlayer.desktopEntry || "") : ""
    readonly property string title:
        hasPlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string artist:
        hasPlayer ? (activePlayer.trackArtist || "") : ""
    readonly property int positionMs: {
        root._positionTick
        if (!hasPlayer || !activePlayer.positionSupported)
            return 0
        return Math.max(0, Math.round(activePlayer.position * 1000))
    }
    readonly property int lengthMs:
        hasPlayer && activePlayer.lengthSupported
            ? Math.max(0, Math.round(activePlayer.length * 1000))
            : 0
    readonly property bool canGoPrevious:
        hasPlayer && activePlayer.canControl && activePlayer.canGoPrevious
    readonly property bool canTogglePlayback:
        hasPlayer && activePlayer.canControl && activePlayer.canTogglePlaying
    readonly property bool canGoNext:
        hasPlayer && activePlayer.canControl && activePlayer.canGoNext
    readonly property bool canSeek:
        hasPlayer && activePlayer.canControl && activePlayer.canSeek && activePlayer.positionSupported
    readonly property string playbackState: {
        if (!hasPlayer)
            return "stopped"
        if (activePlayer.playbackState === MprisPlaybackState.Playing)
            return "playing"
        if (activePlayer.playbackState === MprisPlaybackState.Paused)
            return "paused"
        return "stopped"
    }

    signal mediaChanged()

    function _artPlayerKey(player) {
        if (!player)
            return ""

        return player.identity || player.desktopEntry || ""
    }

    function _artKey(player) {
        if (!player)
            return ""

        return [
            root._artPlayerKey(player),
            player.trackTitle || "",
            player.trackArtist || ""
        ].join("|")
    }

    function _syncArtUrl() {
        if (!root.hasPlayer) {
            root.artUrl = ""
            root._lastArtKey = ""
            root._lastArtPlayerKey = ""
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        const player = root.activePlayer
        const playerKey = root._artPlayerKey(player)
        const artKey = root._artKey(player)
        const nextArtUrl = player.trackArtUrl || ""

        if (nextArtUrl !== "") {
            root._lastArtPlayerKey = playerKey
            root._lastArtKey = artKey
            root.artUrl = nextArtUrl
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        // Keep the previous artwork while the player is replaying or briefly
        // publishing empty metadata for the current track.
        if (playerKey === root._lastArtPlayerKey && (artKey === root._lastArtKey || player.trackTitle === "" || player.trackArtist === "")) {
            if (root._artRecoveryStartedAt === 0)
                root._artRecoveryStartedAt = Date.now()

            root._artRecoveryPending = true
            return
        }

        root._lastArtPlayerKey = playerKey
        root._lastArtKey = artKey
        root.artUrl = ""
        root._artRecoveryStartedAt = Date.now()
        root._artRecoveryPending = true
    }

    function _shouldRetryArtRecovery() {
        if (!root.hasPlayer)
            return false

        if (root.artUrl !== "")
            return false

        if (!root._artRecoveryPending)
            return false

        if (root._artRecoveryStartedAt === 0)
            return true

        return Date.now() - root._artRecoveryStartedAt <= 15000
    }

    function playPause() {
        if (!root.canTogglePlayback)
            return

        if (root.playbackState === "playing")
            root.activePlayer.pause()
        else
            root.activePlayer.play()
    }

    function previous() {
        if (!root.canGoPrevious)
            return

        root.activePlayer.previous()
    }

    function next() {
        if (!root.canGoNext)
            return

        root.activePlayer.next()
    }

    function ipcPlayPause() {
        root.playPause()
    }

    function ipcPrevious() {
        root.previous()
    }

    function ipcNext() {
        root.next()
    }

    function setProgress(progress) {
        if (!root.canSeek || root.lengthMs <= 0)
            return

        root.activePlayer.position = Math.max(0, Math.min(1, progress)) * root.lengthMs / 1000
        root._positionTick++
        root.mediaChanged()
    }

    onActivePlayerChanged: {
        root._syncArtUrl()
        root.mediaChanged()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasPlayer && root.playbackState === "playing"
        onTriggered: root._positionTick++
    }

    // Artwork recovery poll.
    Timer {
        id: _artRecoveryTimer
        interval: 1000
        repeat: true
        running: root._shouldRetryArtRecovery()
        onTriggered: root._syncArtUrl()
    }

    Connections {
        target: Mpris.players
        function onObjectInsertedPost() {
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onObjectRemovedPre() {
            root._syncArtUrl()
            root.mediaChanged()
        }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onTrackArtistChanged() {
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onTrackArtUrlChanged() {
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onPlaybackStateChanged() {
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onIdentityChanged() {
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onDesktopEntryChanged() {
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onPositionChanged() {
            root._positionTick++
            root.mediaChanged()
        }
        function onLengthChanged() { root.mediaChanged() }
        function onCanControlChanged() { root.mediaChanged() }
        function onCanGoPreviousChanged() { root.mediaChanged() }
        function onCanTogglePlayingChanged() { root.mediaChanged() }
        function onCanGoNextChanged() { root.mediaChanged() }
        function onCanSeekChanged() { root.mediaChanged() }
        function onPositionSupportedChanged() { root.mediaChanged() }
        function onLengthSupportedChanged() { root.mediaChanged() }
    }

    IpcHandler {
        target: "media"

        function playPause() { root.ipcPlayPause() }
        function previous() { root.ipcPrevious() }
        function next() { root.ipcNext() }
    }

    Component.onCompleted: root._syncArtUrl()
}
