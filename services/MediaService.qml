pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

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

    onActivePlayerChanged: root.mediaChanged()

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
    }
}