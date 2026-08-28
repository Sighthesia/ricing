pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Normalize the active MPRIS player into a single media state surface.
Singleton {
    id: root

    readonly property bool _artDebugEnabled:
        (Quickshell.env("AFLOAT_MEDIA_ART_DEBUG") || "").trim() === "1"

    property int _positionTick: 0
    property string _preferredPlayerKey: ""
    property var _activePlayerRef: null
    // Sticky lock: when set, the active player stays selected even if another
    // player starts playing, until the locked player stops or disappears.
    property bool _userLockedPlayer: false
    property string _userLockedPlayerKey: ""
    // Debounce timestamp (ms) to suppress auto-switching when multiple players
    // are simultaneously playing; the selection only switches if a different
    // player has been preferred for longer than this window.
    property real _lastSelectionChangeAt: 0
    readonly property real _selectionDebounceMs: 800
    property string artUrl: ""
    property string _lastArtKey: ""
    property string _lastArtPlayerKey: ""
    property string _lastArtTitle: ""
    property string _lastArtArtist: ""
    property bool _artRecoveryPending: false
    property real _artRecoveryStartedAt: 0
    property var _artUrlCache: ({})
    property var _failedArtUrlCache: ({})
    property string _lastSeenArtKey: ""
    property int _cacheVersion: 0
    property var _playerLastPlayingAt: ({})
    property var _playerWasPlaying: ({})

    readonly property var activePlayer: root._activePlayerRef
    readonly property bool hasPlayer: activePlayer !== null
    // Live list of all MPRIS players for control-center listing.
    readonly property var playerList: Mpris.players.values
    readonly property int playerCount: root.playerList.length
    readonly property int activePlayerIndex: {
        const players = root.playerList
        const current = root.activePlayer
        if (!current)
            return -1

        for (let i = 0; i < players.length; i += 1) {
            if (players[i] === current)
                return i
        }
        return -1
    }
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

    function _cloneArtCache(cache) {
        if (!cache || typeof cache !== "object")
            return ({})

        return Object.assign({}, cache)
    }

    function _debugArtLog(event, player, artUrl, extra) {
        if (!root._artDebugEnabled)
            return

        const safePlayer = player || root.activePlayer
        const payload = {
            event: event,
            player: safePlayer ? (safePlayer.identity || safePlayer.desktopEntry || "") : "",
            title: safePlayer ? (safePlayer.trackTitle || "") : "",
            artist: safePlayer ? (safePlayer.trackArtist || "") : "",
            trackArtUrl: safePlayer ? root._normalizeArtUrl(safePlayer.trackArtUrl || "") : "",
            artUrl: root._normalizeArtUrl(artUrl != null ? artUrl : root.artUrl),
            failed: root._isFailedArtUrl(artUrl != null ? artUrl : root.artUrl),
            recoveryPending: root._artRecoveryPending,
            recoveryStartedAt: root._artRecoveryStartedAt
        }

        if (extra && typeof extra === "object")
            Object.assign(payload, extra)

        console.log("[afloat:MediaArt]", JSON.stringify(payload))
    }

    function _rememberArtContext(playerKey, artKey, trackTitle, trackArtist) {
        root._lastArtPlayerKey = playerKey
        root._lastArtKey = artKey
        root._lastArtTitle = trackTitle
        root._lastArtArtist = trackArtist
    }

    function _applyLoadedArtCache(cache) {
        root._artUrlCache = root._cloneArtCache(cache)

        if (root.hasPlayer)
            root._syncArtUrl()
    }

    // Unique per player instance: two windows of the same app are distinct
    // D-Bus names. identity/desktopEntry alone would conflate them.
    function _artPlayerKey(player) {
        if (!player)
            return ""

        const dbusName = root._normalizeArtUrl(player.dbusName || "")
        if (dbusName !== "")
            return dbusName

        if (player.uniqueId !== undefined && player.uniqueId !== null && player.uniqueId !== "")
            return "uid:" + player.uniqueId

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
        const normalizedArtUrl = root._normalizeArtUrl(artUrl)
        if (!artKey || !normalizedArtUrl)
            return

        const cache = root._cloneArtCache(root._artUrlCache)
        const keys = Object.keys(cache)
        if (keys.length >= 200) {
            const oldestKey = keys[0]
            delete cache[oldestKey]
        }
        cache[artKey] = normalizedArtUrl
        root._artUrlCache = cache
        root._cacheVersion += 1
        artCacheAdapter.artUrlCache = cache
        artCacheSaveTimer.restart()
    }

    function _normalizeArtUrl(artUrl) {
        return artUrl != null ? String(artUrl).trim() : ""
    }

    function _lookupCachedArtUrl(artKey) {
        if (!artKey)
            return ""

        const cachedArtUrl = root._artUrlCache[artKey] || ""
        return root._isFailedArtUrl(cachedArtUrl) ? "" : cachedArtUrl
    }

    function _isFailedArtUrl(artUrl) {
        const normalizedArtUrl = root._normalizeArtUrl(artUrl)
        return !!(normalizedArtUrl && root._failedArtUrlCache[normalizedArtUrl])
    }

    function _rememberFailedArtUrl(artUrl) {
        const normalizedArtUrl = root._normalizeArtUrl(artUrl)
        if (!normalizedArtUrl || root._isFailedArtUrl(normalizedArtUrl))
            return

        const failedCache = root._cloneArtCache(root._failedArtUrlCache)
        failedCache[normalizedArtUrl] = true
        root._failedArtUrlCache = failedCache
    }

    function reportArtLoadFailure(artUrl) {
        const failedArtUrl = root._normalizeArtUrl(artUrl)
        if (!failedArtUrl)
            return

        root._rememberFailedArtUrl(failedArtUrl)
        root._debugArtLog("load-failure", root.activePlayer, failedArtUrl)

        if (root._normalizeArtUrl(root.artUrl) === failedArtUrl) {
            root.artUrl = ""
            root._artRecoveryPending = root.hasPlayer && root._artKey(root.activePlayer) !== ""
            root._artRecoveryStartedAt = root._artRecoveryPending ? Date.now() : 0
        }

        if (root.hasPlayer)
            root._syncArtUrl()
    }

    function _selectActivePlayer() {
        const players = Mpris.players.values
        let preferredPlayer = null
        let bestPlayingPlayer = null
        let bestPlayingAt = -1

        // Track when each player last transitioned to playing so the most
        // recently started playing player can preempt, and pausing a newer
        // player immediately falls back to the still-playing previous one.
        const wasPlayingMap = root._playerWasPlaying || {}
        const playingAtMap = Object.assign({}, root._playerLastPlayingAt || {})
        let playingAtDirty = false
        let wasPlayingDirty = false

        for (let index = 0; index < players.length; index += 1) {
            const player = players[index]
            if (!player)
                continue

            const playerKey = root._artPlayerKey(player)

            if (playerKey !== "" && playerKey === root._preferredPlayerKey)
                preferredPlayer = player

            const isPlaying = !!player.isPlaying
            const wasPlaying = !!wasPlayingMap[playerKey]
            if (isPlaying && !wasPlaying) {
                playingAtMap[playerKey] = Date.now()
                playingAtDirty = true
            }
            if (wasPlaying !== isPlaying) {
                wasPlayingMap[playerKey] = isPlaying
                wasPlayingDirty = true
            }

            if (isPlaying) {
                const at = playingAtMap[playerKey] || 0
                if (bestPlayingPlayer === null || at >= bestPlayingAt) {
                    bestPlayingPlayer = player
                    bestPlayingAt = at
                }
            }
        }

        // Prune stale keys for players that disappeared
        const liveKeys = {}
        for (let p = 0; p < players.length; p += 1) {
            const k = root._artPlayerKey(players[p])
            if (k !== "")
                liveKeys[k] = true
        }
        for (const k in playingAtMap) {
            if (!liveKeys[k]) {
                delete playingAtMap[k]
                playingAtDirty = true
            }
        }
        for (const k in wasPlayingMap) {
            if (!liveKeys[k]) {
                delete wasPlayingMap[k]
                wasPlayingDirty = true
            }
        }

        if (playingAtDirty)
            root._playerLastPlayingAt = playingAtMap
        if (wasPlayingDirty)
            root._playerWasPlaying = wasPlayingMap

        // User-locked player takes priority until it stops or disappears.
        if (root._userLockedPlayer && root._userLockedPlayerKey !== "") {
            let lockedPlayer = null
            for (let index = 0; index < players.length; index += 1) {
                const player = players[index]
                if (player && root._artPlayerKey(player) === root._userLockedPlayerKey) {
                    lockedPlayer = player
                    break
                }
            }

            if (lockedPlayer) {
                const stillPlaying = lockedPlayer.isPlaying
                    || lockedPlayer.playbackState === MprisPlaybackState.Paused
                if (stillPlaying)
                    return lockedPlayer
            }
            // Locked player gone or stopped — release the lock.
            root._userLockedPlayer = false
            root._userLockedPlayerKey = ""
        }

        const current = root._activePlayerRef
        const currentKey = root._artPlayerKey(current)

        // Prefer any currently playing player. The most recently started
        // playing player wins, so a newly started player preempts the previous
        // one, and when that new player pauses we immediately fall back to the
        // still-playing previous one without debounce churn.
        if (bestPlayingPlayer !== null) {
            const candidateKey = root._artPlayerKey(bestPlayingPlayer)
            if (currentKey !== candidateKey)
                root._lastSelectionChangeAt = Date.now()
            return bestPlayingPlayer
        }

        if (preferredPlayer !== null)
            return preferredPlayer

        // Fall back to the current player if it still exists, even when paused,
        // so the bar does not flash empty on transient play/pause toggles.
        if (current)
            return current

        return players.length > 0 ? players[0] : null
    }

    function _syncActivePlayer() {
        const nextPlayer = root._selectActivePlayer()
        const previousKey = root._artPlayerKey(root._activePlayerRef)
        const nextKey = root._artPlayerKey(nextPlayer)
        if (previousKey !== nextKey)
            root._lastSelectionChangeAt = Date.now()

        root._activePlayerRef = nextPlayer
        root._preferredPlayerKey = nextKey
    }

    // User-selected active player from the control center; locks selection
    // until the user picks another, or the player stops/leaves.
    function setActivePlayer(playerKey) {
        const normalizedKey = playerKey != null ? String(playerKey) : ""
        if (normalizedKey === "")
            return

        const players = Mpris.players.values
        for (let index = 0; index < players.length; index += 1) {
            const player = players[index]
            if (player && root._artPlayerKey(player) === normalizedKey) {
                root._userLockedPlayer = true
                root._userLockedPlayerKey = normalizedKey
                root._activePlayerRef = player
                root._preferredPlayerKey = normalizedKey
                root._lastSelectionChangeAt = Date.now()
                root._syncArtUrl()
                root.mediaChanged()
                return
            }
        }
    }

    function clearActivePlayerLock() {
        root._userLockedPlayer = false
        root._userLockedPlayerKey = ""
        root._syncActivePlayer()
        root._syncArtUrl()
        root.mediaChanged()
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
        const nextArtUrl = root._normalizeArtUrl(player.trackArtUrl || "")
        const trackChanged = artKey !== root._lastSeenArtKey

        // Track changed: reset recovery timer so new track gets full window.
        if (trackChanged) {
            root._lastSeenArtKey = artKey
            root._artRecoveryStartedAt = 0
        }

        const cachedArt = root._lookupCachedArtUrl(artKey)
        root._debugArtLog("sync", player, nextArtUrl, {
            trackChanged: trackChanged,
            artKey: artKey,
            cachedArt: cachedArt,
            failedTrackArtUrl: root._isFailedArtUrl(nextArtUrl),
            failedCurrentArtUrl: root._isFailedArtUrl(root.artUrl)
        })

        // Player provides art URL directly: use and cache it.
        if (nextArtUrl !== "" && !root._isFailedArtUrl(nextArtUrl)) {
            root._rememberArtContext(playerKey, artKey, trackTitle, trackArtist)
            root.artUrl = nextArtUrl
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            root._cacheArtUrl(artKey, nextArtUrl)
            return
        }

        if (nextArtUrl !== "" && root._isFailedArtUrl(nextArtUrl)) {
            root._rememberArtContext(playerKey, artKey, trackTitle, trackArtist)
            root.artUrl = ""
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        // Art URL empty: check track-level cache for previously seen art.
        if (cachedArt !== "") {
            root._rememberArtContext(playerKey, artKey, trackTitle, trackArtist)
            root.artUrl = cachedArt
            root._artRecoveryPending = false
            root._artRecoveryStartedAt = 0
            return
        }

        // New track without art yet: clear the previous track's cover immediately.
        if (trackChanged) {
            root._rememberArtContext(playerKey, artKey, trackTitle, trackArtist)
            root.artUrl = ""
            root._artRecoveryPending = artKey !== ""
            root._artRecoveryStartedAt = root._artRecoveryPending ? Date.now() : 0
            return
        }

        // No cache hit: enter recovery mode to wait for delayed art URL.
        if (root.artUrl !== "" && artKey !== "" && artKey === root._lastArtKey
                && playerKey === root._lastArtPlayerKey) {
            if (root._artRecoveryStartedAt === 0)
                root._artRecoveryStartedAt = Date.now()

            const timeout = root._artRecoveryTimeout(player)
            root._artRecoveryPending = true
            if (Date.now() - root._artRecoveryStartedAt <= timeout)
                return

            root.artUrl = ""
        }

        root._rememberArtContext(playerKey, artKey, trackTitle, trackArtist)
        if (root.artUrl === "") {
            root._artRecoveryPending = artKey !== ""
            root._artRecoveryStartedAt = root._artRecoveryPending && root._artRecoveryStartedAt === 0
                ? Date.now()
                : root._artRecoveryStartedAt
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
        root._syncActivePlayer()
        root._syncArtUrl()
    }

    // Persist the art URL cache across shell reloads.
    property FileView artCacheFile: FileView {
        id: artCacheFile

        path: Quickshell.cacheDir + "/media-art-cache.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: root._applyLoadedArtCache(artCacheAdapter.artUrlCache)
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                artCacheFile.writeAdapter()
            } else {
                console.warn("MediaService: failed to load media-art-cache.json, error =", error)
            }
        }

        JsonAdapter {
            id: artCacheAdapter
            property var artUrlCache: ({})
        }
    }
}
