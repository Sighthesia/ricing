pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Normalizes active MPRIS player state into one widget-friendly media source.
Singleton {
    id: root

    property int _positionTick: 0
    property string _preferredPlayerKey: ""
    property var _activePlayerRef: null
    property string artUrl: ""
    property string _lastArtKey: ""
    property string _lastArtPlayerKey: ""
    property string _lastArtTitle: ""
    property string _lastArtArtist: ""
    property bool _artRecoveryPending: false
    property int _artRecoveryStartedAt: 0

    readonly property var activePlayer: root._activePlayerRef

    function _selectActivePlayer() {
        const players = Mpris.players.values
        let preferredPlayer = null
        let firstPlayingPlayer = null

        for (let i = 0; i < players.length; i++) {
            const player = players[i]
            const playerKey = root._artPlayerKey(player)

            if (playerKey !== "" && playerKey === root._preferredPlayerKey)
                preferredPlayer = player

            if (firstPlayingPlayer === null && player.isPlaying)
                firstPlayingPlayer = player
        }

        if (preferredPlayer !== null && preferredPlayer.isPlaying)
            return preferredPlayer

        if (firstPlayingPlayer !== null)
            return firstPlayingPlayer

        if (preferredPlayer !== null)
            return preferredPlayer

        return players.length > 0 ? players[0] : null
    }

    function _syncActivePlayer() {
        const nextPlayer = root._selectActivePlayer()
        root._activePlayerRef = nextPlayer
        root._preferredPlayerKey = root._artPlayerKey(nextPlayer)
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
            root._lastArtTitle = ""
            root._lastArtArtist = ""
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        const player = root.activePlayer
        const playerKey = root._artPlayerKey(player)
        const artKey = root._artKey(player)
        const trackTitle = player.trackTitle || ""
        const trackArtist = player.trackArtist || ""
        const nextArtUrl = player.trackArtUrl || ""

        if (nextArtUrl === "" && root.artUrl !== "" && playerKey === root._lastArtPlayerKey && trackTitle === root._lastArtTitle && trackArtist === root._lastArtArtist) {
            root._artRecoveryPending = true
            if (root._artRecoveryStartedAt === 0)
                root._artRecoveryStartedAt = Date.now()
            return
        }

        if (nextArtUrl !== "") {
            root._lastArtPlayerKey = playerKey
            root._lastArtKey = artKey
            root._lastArtTitle = trackTitle
            root._lastArtArtist = trackArtist
            root.artUrl = nextArtUrl
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        // Keep the previous artwork while the player is replaying or briefly
        // publishing empty metadata for the current track.
        if (playerKey === root._lastArtPlayerKey && (artKey === root._lastArtKey || trackTitle === "" || trackArtist === "")) {
            if (root._artRecoveryStartedAt === 0)
                root._artRecoveryStartedAt = Date.now()

            root._artRecoveryPending = true
            return
        }

        root._lastArtPlayerKey = playerKey
        root._lastArtKey = artKey
        root._lastArtTitle = trackTitle
        root._lastArtArtist = trackArtist
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
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onObjectRemovedPre() {
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onTrackArtistChanged() {
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onTrackArtUrlChanged() {
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onPlaybackStateChanged() {
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onIdentityChanged() {
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onDesktopEntryChanged() {
            root._syncActivePlayer()
            root._syncArtUrl()
            root.mediaChanged()
        }
        function onPositionChanged() {
            root._syncActivePlayer()
            root._positionTick++
            root.mediaChanged()
        }
        function onLengthChanged() { root._syncActivePlayer(); root.mediaChanged() }
        function onCanControlChanged() { root._syncActivePlayer(); root.mediaChanged() }
        function onCanGoPreviousChanged() { root._syncActivePlayer(); root.mediaChanged() }
        function onCanTogglePlayingChanged() { root._syncActivePlayer(); root.mediaChanged() }
        function onCanGoNextChanged() { root._syncActivePlayer(); root.mediaChanged() }
        function onCanSeekChanged() { root._syncActivePlayer(); root.mediaChanged() }
        function onPositionSupportedChanged() { root._syncActivePlayer(); root.mediaChanged() }
        function onLengthSupportedChanged() { root._syncActivePlayer(); root.mediaChanged() }
    }

    IpcHandler {
        target: "media"

        function playPause() { root.ipcPlayPause() }
        function previous() { root.ipcPrevious() }
        function next() { root.ipcNext() }
    }

    Component.onCompleted: {
        root._syncActivePlayer()
        root._syncArtUrl()
    }
}
