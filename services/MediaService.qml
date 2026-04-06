pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Normalizes active MPRIS player state into one widget-friendly media source.
Singleton {
    id: root

    property int _positionTick: 0

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
    readonly property string artUrl:
        hasPlayer ? (activePlayer.trackArtUrl || "") : ""
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

    function setProgress(progress) {
        if (!root.canSeek || root.lengthMs <= 0)
            return

        root.activePlayer.position = Math.max(0, Math.min(1, progress)) * root.lengthMs / 1000
        root._positionTick++
        root.mediaChanged()
    }

    onActivePlayerChanged: root.mediaChanged()

    Timer {
        interval: 1000
        repeat: true
        running: root.hasPlayer && root.playbackState === "playing"
        onTriggered: root._positionTick++
    }

    Connections {
        target: Mpris.players
        function onObjectInsertedPost() { root.mediaChanged() }
        function onObjectRemovedPre() { root.mediaChanged() }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root.mediaChanged() }
        function onTrackArtistChanged() { root.mediaChanged() }
        function onTrackArtUrlChanged() { root.mediaChanged() }
        function onPlaybackStateChanged() { root.mediaChanged() }
        function onIdentityChanged() { root.mediaChanged() }
        function onDesktopEntryChanged() { root.mediaChanged() }
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
}
