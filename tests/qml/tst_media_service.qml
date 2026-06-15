import QtQuick
import QtTest
import Quickshell.Services.Mpris
import "../../services" as Services

// Exercise MediaService cover recovery and track change handling.
TestCase {
    name: "MediaService"

    function makePlayer(title, artist, artUrl) {
        return {
            identity: "Firefox",
            desktopEntry: "firefox",
            trackTitle: title,
            trackArtist: artist,
            trackAlbum: "Album",
            trackArtUrl: artUrl || "",
            positionSupported: true,
            position: 0,
            lengthSupported: true,
            length: 5,
            canControl: true,
            canGoPrevious: true,
            canTogglePlaying: true,
            canGoNext: true,
            canSeek: true,
            playbackState: MprisPlaybackState.Playing,
            isPlaying: true,
            play: function() {},
            pause: function() {},
            previous: function() {},
            next: function() {}
        }
    }

    function resetMediaState() {
        Services.MediaService._activePlayerRef = null
        Services.MediaService._preferredPlayerKey = ""
        Services.MediaService._positionTick = 0
        Services.MediaService.artUrl = ""
        Services.MediaService._lastArtKey = ""
        Services.MediaService._lastArtPlayerKey = ""
        Services.MediaService._lastArtTitle = ""
        Services.MediaService._lastArtArtist = ""
        Services.MediaService._artRecoveryPending = false
        Services.MediaService._artRecoveryStartedAt = 0
        Services.MediaService._failedArtUrlCache = ({})
        Services.MediaService._lastSeenArtKey = ""
        Services.MediaService._cacheVersion = 0
        Services.MediaService._applyLoadedArtCache({})
    }

    function test_loaded_cache_restores_cover_for_current_track() {
        resetMediaState()

        Services.MediaService._activePlayerRef = makePlayer("Song", "Artist", "")
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "")

        Services.MediaService._applyLoadedArtCache({
            "Firefox|Song|Artist": "file:///tmp/song-cover.jpg"
        })

        compare(Services.MediaService.artUrl, "file:///tmp/song-cover.jpg")
        compare(Services.MediaService._artRecoveryPending, false)
    }

    function test_track_change_clears_previous_cover_until_new_cover_arrives() {
        resetMediaState()

        const player = makePlayer("Song One", "Artist", "file:///tmp/song-one.jpg")
        Services.MediaService._activePlayerRef = player
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "file:///tmp/song-one.jpg")

        player.trackTitle = "Song Two"
        player.trackArtUrl = ""
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "")
        compare(Services.MediaService._artRecoveryPending, true)

        player.trackArtUrl = "file:///tmp/song-two.jpg"
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "file:///tmp/song-two.jpg")
        compare(Services.MediaService._artRecoveryPending, false)
    }

    function test_player_switch_clears_previous_cover_until_new_player_art_arrives() {
        resetMediaState()

        const firstPlayer = makePlayer("Song One", "Artist A", "file:///tmp/song-one.jpg")
        Services.MediaService._activePlayerRef = firstPlayer
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "file:///tmp/song-one.jpg")

        const secondPlayer = makePlayer("Song Two", "Artist B", "")
        secondPlayer.identity = "Spotify"
        secondPlayer.desktopEntry = "spotify"
        Services.MediaService._activePlayerRef = secondPlayer
        Services.MediaService._preferredPlayerKey = "Spotify"
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "")
        compare(Services.MediaService._artRecoveryPending, true)

        secondPlayer.trackArtUrl = "file:///tmp/song-two.jpg"
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "file:///tmp/song-two.jpg")
        compare(Services.MediaService._artRecoveryPending, false)
    }

    function test_failed_art_url_is_ignored_after_load_failure() {
        resetMediaState()

        const player = makePlayer("Song One", "Artist", "file:///tmp/bad-cover.jpg")
        Services.MediaService._activePlayerRef = player
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.MediaService._syncArtUrl()

        compare(Services.MediaService.artUrl, "file:///tmp/bad-cover.jpg")

        Services.MediaService.reportArtLoadFailure("file:///tmp/bad-cover.jpg")

        compare(Services.MediaService.artUrl, "")
        compare(Services.MediaService._artRecoveryPending, false)
        compare(Services.MediaService._failedArtUrlCache["file:///tmp/bad-cover.jpg"], true)
        compare(Services.MediaService._isFailedArtUrl("file:///tmp/bad-cover.jpg"), true)

        Services.MediaService._syncArtUrl()
        compare(Services.MediaService.artUrl, "")
        compare(Services.MediaService._artRecoveryPending, false)

        player.trackArtUrl = "file:///tmp/good-cover.jpg"
        Services.MediaService._syncArtUrl()
        compare(Services.MediaService.artUrl, "file:///tmp/good-cover.jpg")
    }
}
