pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Normalize the active MPRIS player into a single media state surface.
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
    property var _artUrlCache: ({})
    property string _lastSeenArtKey: ""
    property int _cacheVersion: 0

    readonly property var activePlayer: root._activePlayerRef
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool playing: root.playbackState === "playing"
    readonly property string playerName:
        hasPlayer ? (activePlayer.identity || activePlayer.desktopEntry || "") : ""
    readonly property string desktopEntry:
        hasPlayer ? (activePlayer.desktopEntry || "") : ""
    readonly property string title:
        hasPlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string artist:
        hasPlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string album:
        hasPlayer ? (activePlayer.trackAlbum || "") : ""
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

    function _isBrowserPlayer(player) {
        if (!player)
            return false
        const identity = (player.identity || "").toLowerCase()
        const desktopEntry = (player.desktopEntry || "").toLowerCase()
        return identity.indexOf("firefox") !== -1
            || identity.indexOf("chromium") !== -1
            || identity.indexOf("chrome") !== -1
            || desktopEntry.indexOf("firefox") !== -1
            || desktopEntry.indexOf("chromium") !== -1
            || desktopEntry.indexOf("chrome") !== -1
    }

    function _artRecoveryTimeout(player) {
        return root._isBrowserPlayer(player) ? 30000 : 15000
    }

    function _cacheArtUrl(artKey, artUrl) {
        if (!artKey || !artUrl)
            return
        const cache = root._artUrlCache
        const keys = Object.keys(cache)
        if (keys.length >= 200) {
            const oldestKey = keys[0]
            delete cache[oldestKey]
        }
        cache[artKey] = artUrl
        root._artUrlCache = cache
        root._cacheVersion += 1
        artCacheAdapter.artUrlCache = cache
        artCacheSaveTimer.restart()
    }

    function _lookupCachedArtUrl(artKey) {
        if (!artKey)
            return ""
        return root._artUrlCache[artKey] || ""
    }

    function _selectActivePlayer() {
        const players = Mpris.players.values
        let preferredPlayer = null
        let firstPlayingPlayer = null

        for (let index = 0; index < players.length; index += 1) {
            const player = players[index]
            if (!player)
                continue

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

    function _syncArtUrl() {
        if (!root.hasPlayer) {
            root.artUrl = ""
            root._lastArtKey = ""
            root._lastArtPlayerKey = ""
            root._lastArtTitle = ""
            root._lastArtArtist = ""
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            root._lastSeenArtKey = ""
            return
        }

        const player = root.activePlayer
        if (!player) {
            root.artUrl = ""
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        const playerKey = root._artPlayerKey(player)
        const artKey = root._artKey(player)
        const trackTitle = player.trackTitle || ""
        const trackArtist = player.trackArtist || ""
        const nextArtUrl = player.trackArtUrl || ""

        // Track changed: reset recovery timer so new track gets full window.
        if (artKey !== root._lastSeenArtKey) {
            root._lastSeenArtKey = artKey
            root._artRecoveryStartedAt = 0
        }

        // Player provides art URL directly: use and cache it.
        if (nextArtUrl !== "") {
            root._lastArtPlayerKey = playerKey
            root._lastArtKey = artKey
            root._lastArtTitle = trackTitle
            root._lastArtArtist = trackArtist
            root.artUrl = nextArtUrl
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            root._cacheArtUrl(artKey, nextArtUrl)
            return
        }

        // Art URL empty: check track-level cache for previously seen art.
        const cachedArt = root._lookupCachedArtUrl(artKey)
        if (cachedArt !== "") {
            root._lastArtPlayerKey = playerKey
            root._lastArtKey = artKey
            root._lastArtTitle = trackTitle
            root._lastArtArtist = trackArtist
            root.artUrl = cachedArt
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        // No cache hit: enter recovery mode to wait for delayed art URL.
        if (root.artUrl !== "" && playerKey === root._lastArtPlayerKey) {
            if (root._artRecoveryStartedAt === 0)
                root._artRecoveryStartedAt = Date.now()

            const timeout = root._artRecoveryTimeout(player)
            root._artRecoveryPending = true
            if (Date.now() - root._artRecoveryStartedAt <= timeout)
                return

            root.artUrl = ""
        }

        root._lastArtPlayerKey = playerKey
        root._lastArtKey = artKey
        root._lastArtTitle = trackTitle
        root._lastArtArtist = trackArtist
        if (root.artUrl === "") {
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
        } else {
            root._artRecoveryPending = true
            if (root._artRecoveryStartedAt === 0)
                root._artRecoveryStartedAt = Date.now()
        }
    }

    function _shouldRetryArtRecovery() {
        if (!root.hasPlayer || !root._artRecoveryPending)
            return false

        if (root._artRecoveryStartedAt === 0)
            return true

        const timeout = root._artRecoveryTimeout(root.activePlayer)
        return Date.now() - root._artRecoveryStartedAt <= timeout
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
        if (root.canGoPrevious)
            root.activePlayer.previous()
    }

    function next() {
        if (root.canGoNext)
            root.activePlayer.next()
    }

    function setProgress(progress) {
        if (!root.canSeek || root.lengthMs <= 0)
            return

        root.activePlayer.position = Math.max(0, Math.min(1, progress)) * root.lengthMs / 1000
        root._positionTick += 1
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
        onTriggered: {
            root._syncActivePlayer()
            root._positionTick += 1
        }
    }

    // Rescan the player list so newly playing players can take focus.
    Timer {
        interval: 1000
        repeat: true
        running: Mpris.players.values.length > 0
        onTriggered: {
            root._syncActivePlayer()
            root._syncArtUrl()
        }
    }

    // Retry art recovery while the player publishes incomplete metadata.
    Timer {
        id: artRecoveryTimer

        interval: 1000
        repeat: true
        running: root._shouldRetryArtRecovery()
        onTriggered: root._syncArtUrl()
    }

    // Debounce saving the art URL cache to disk.
    Timer {
        id: artCacheSaveTimer
        interval: 500
        repeat: false
        onTriggered: artCacheFile.writeAdapter()
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

        function onTrackAlbumChanged() {
            root._syncActivePlayer()
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
            root._positionTick += 1
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

    // Preserve the existing MediaService IPC target for niri keybind compatibility.
    IpcHandler {
        target: "MediaService"

        function playPause() { root.playPause() }
        function previous() { root.previous() }
        function next() { root.next() }
    }

    Component.onCompleted: {
        if (Object.keys(artCacheAdapter.artUrlCache).length > 0)
            root._artUrlCache = artCacheAdapter.artUrlCache
        root._syncActivePlayer()
        root._syncArtUrl()
    }

    // Persist the art URL cache across shell reloads.
    property FileView artCacheFile: FileView {
        id: artCacheFile
        path: Quickshell.cacheDir + "/media-art-cache.json"
        blockLoading: true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                artCacheFile.writeAdapter()
        }

        JsonAdapter {
            id: artCacheAdapter
            property var artUrlCache: ({})
        }
    }
}
