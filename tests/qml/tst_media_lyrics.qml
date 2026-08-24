import QtQuick
import QtTest
import Quickshell.Services.Mpris
import "../../services" as Services

// Exercise lyric timeline fallback and compact lyric updates.
TestCase {
    name: "MediaLyrics"

    function makePlayer(positionMs) {
        return {
            identity: "Firefox",
            desktopEntry: "firefox",
            trackTitle: "Song",
            trackArtist: "Artist",
            trackAlbum: "Album",
            trackArtUrl: "",
            positionSupported: true,
            position: positionMs / 1000,
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

    function resetState() {
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

        Services.NeteaseWebLyricsService._resetState()
        Services.MediaControlService._resetLyricsLatch()
    }

    function test_compact_lyric_updates_when_current_line_changes() {
        resetState()

        Services.NeteaseWebLyricsService.currentLyric = "Line one"
        Services.NeteaseWebLyricsService.nextLyric = "Line two"
        Services.NeteaseWebLyricsService.hasLyrics = true

        tryVerify(function() {
            return Services.MediaControlService.compactPrimaryLyric === "Line one"
        }, 1000)

        Services.NeteaseWebLyricsService.currentLyric = "Line two"
        Services.NeteaseWebLyricsService.nextLyric = "Line three"

        tryVerify(function() {
            return Services.MediaControlService.compactPrimaryLyric === "Line two"
        }, 1000)
    }

    function test_compact_translated_lyric_updates_with_current_line() {
        resetState()

        Services.NeteaseWebLyricsService.currentLyric = "Line one"
        Services.NeteaseWebLyricsService.currentTranslatedLyric = "第一行"
        Services.NeteaseWebLyricsService.nextLyric = "Line two"
        Services.NeteaseWebLyricsService.nextTranslatedLyric = "第二行"
        Services.NeteaseWebLyricsService.hasLyrics = true

        tryVerify(function() {
            return Services.MediaControlService.compactOriginalLyric === "Line one"
                && Services.MediaControlService.compactTranslatedLyric === "第一行"
        }, 1000)

        Services.NeteaseWebLyricsService.currentLyric = "Line two"
        Services.NeteaseWebLyricsService.currentTranslatedLyric = "第二行"

        tryVerify(function() {
            return Services.MediaControlService.compactOriginalLyric === "Line two"
                && Services.MediaControlService.compactTranslatedLyric === "第二行"
        }, 1000)
    }

    function test_translated_only_lyric_can_drive_compact_display() {
        resetState()

        Services.NeteaseWebLyricsService.currentTranslatedLyric = "Translated only"
        Services.NeteaseWebLyricsService.hasLyrics = true

        tryVerify(function() {
            return Services.MediaControlService.compactOriginalLyric === ""
                && Services.MediaControlService.compactTranslatedLyric === "Translated only"
        }, 1000)

        compare(Services.MediaControlService.showCompactLyric, true)
    }

    function test_lyric_window_falls_back_to_media_position_when_web_timeline_stalls() {
        resetState()

        Services.MediaService._activePlayerRef = makePlayer(1200)
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.MediaService._positionTick += 1

        Services.NeteaseWebLyricsService._applyPayload({
            songId: "1",
            title: "Song",
            artist: "Artist",
            playbackState: "paused",
            positionMs: 0,
            durationMs: 5000,
            rawLyric: "[00:00.00]Line one\n[00:01.00]Line two"
        })

        compare(Services.NeteaseWebLyricsService.currentLyric, "Line two")
    }

    function test_lyric_window_matches_media_position_with_artist_format_differences() {
        resetState()

        Services.MediaService._activePlayerRef = {
            identity: "Firefox",
            desktopEntry: "firefox",
            trackTitle: "Song Name",
            trackArtist: "Artist A / Artist B",
            trackAlbum: "Album",
            trackArtUrl: "",
            positionSupported: true,
            position: 1.2,
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
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.MediaService._positionTick += 1

        Services.NeteaseWebLyricsService._applyPayload({
            songId: "2",
            title: " song name ",
            artist: "artist a, artist b",
            playbackState: "paused",
            positionMs: 0,
            durationMs: 5000,
            rawLyric: "[00:00.00]Line one\n[00:01.00]Line two"
        })

        compare(Services.NeteaseWebLyricsService.currentLyric, "Line two")
    }

    function test_compact_lyric_survives_metadata_case_and_separator_churn() {
        resetState()

        Services.MediaService._activePlayerRef = makePlayer(0)
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.NeteaseWebLyricsService.songId = ""
        Services.NeteaseWebLyricsService.title = "Song Name"
        Services.NeteaseWebLyricsService.artist = "Artist A, Artist B"
        Services.NeteaseWebLyricsService.currentLyric = "Line one"
        Services.NeteaseWebLyricsService.hasLyrics = true
        Services.MediaControlService._refreshLyricsSession()

        tryVerify(function() {
            return Services.MediaControlService.compactPrimaryLyric === "Line one"
        }, 1000)

        Services.MediaService._activePlayerRef.trackTitle = " song name "
        Services.MediaService._activePlayerRef.trackArtist = "Artist A / Artist B"
        Services.NeteaseWebLyricsService.title = "SONG NAME"
        Services.NeteaseWebLyricsService.artist = "artist a / artist b"
        Services.MediaControlService._refreshLyricsSession()

        compare(Services.MediaControlService.compactPrimaryLyric, "Line one")
        compare(Services.MediaControlService._lyricsSourceLatched, true)
    }

    function test_compact_lyric_survives_temporary_empty_media_artist() {
        resetState()

        Services.MediaService._activePlayerRef = makePlayer(0)
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.NeteaseWebLyricsService.title = "Song"
        Services.NeteaseWebLyricsService.artist = "Artist"
        Services.NeteaseWebLyricsService.currentLyric = "Line one"
        Services.NeteaseWebLyricsService.hasLyrics = true
        Services.MediaControlService._refreshLyricsSession()

        tryVerify(function() {
            return Services.MediaControlService.compactPrimaryLyric === "Line one"
        }, 1000)

        Services.MediaService._activePlayerRef.trackArtist = ""
        Services.MediaControlService._refreshLyricsSession()
        compare(Services.MediaControlService.compactPrimaryLyric, "Line one")
        compare(Services.MediaControlService._lyricsSourceLatched, true)

        Services.MediaService._activePlayerRef.trackArtist = "Artist"
        Services.MediaControlService._refreshLyricsSession()
        compare(Services.MediaControlService.compactPrimaryLyric, "Line one")
        compare(Services.MediaControlService._lyricsSourceLatched, true)
    }

    function test_web_art_url_is_preferred_when_mpris_cover_missing() {
        resetState()

        Services.MediaService._activePlayerRef = makePlayer(0)
        Services.MediaService._preferredPlayerKey = "Firefox"
        Services.MediaService.artUrl = ""
        Services.NeteaseWebLyricsService.artUrl = "file:///tmp/web-cover.jpg"

        compare(Services.MediaControlService.artUrl, "file:///tmp/web-cover.jpg")

        Services.MediaService.artUrl = "file:///tmp/mpris-cover.jpg"
        compare(Services.MediaControlService.artUrl, "file:///tmp/mpris-cover.jpg")
    }

    function test_compact_display_uses_title_before_first_lyric_without_secondary() {
        resetState()

        Services.NeteaseWebLyricsService.title = "Song"
        Services.NeteaseWebLyricsService.artist = "Artist"
        Services.NeteaseWebLyricsService.nextLyric = "Line one"
        Services.NeteaseWebLyricsService.nextTranslatedLyric = "第一行"
        Services.NeteaseWebLyricsService.hasLyrics = true

        Services.MediaControlService._refreshLyricsSession()

        compare(Services.MediaControlService.compactOriginalLyric, "Song")
        compare(Services.MediaControlService.compactTranslatedLyric, "")
        compare(Services.MediaControlService.showCompactLyric, true)
    }

    function test_instrumental_lyric_should_not_display_compact_lyric() {
        resetState()

        Services.NeteaseWebLyricsService.currentLyric = "纯音乐，请欣赏"
        Services.NeteaseWebLyricsService.hasLyrics = true

        tryVerify(function() {
            return Services.MediaControlService.compactPrimaryLyric === ""
        }, 1000)

        compare(Services.MediaControlService.showCompactLyric, false)
    }

    function test_paused_session_survives_stale_payload_silence() {
        resetState()

        Services.NeteaseWebLyricsService._applyPayload({
            songId: "9",
            title: "Song",
            artist: "Artist",
            playbackState: "paused",
            positionMs: 1200,
            durationMs: 5000,
            rawLyric: "[00:00.00]Line one\n[00:01.00]Line two",
            translatedLyric: "[00:01.00]第二行"
        })
        compare(Services.NeteaseWebLyricsService.playbackState, "paused")

        // A paused page stops emitting payloads (signature dedupe); the
        // loaded session must not be wiped by stale-silence detection.
        Services.NeteaseWebLyricsService._lastUpdateMs = Date.now() - 60000
        Services.NeteaseWebLyricsService._clearIfStale()

        compare(Services.NeteaseWebLyricsService.songId, "9")
        compare(Services.NeteaseWebLyricsService.currentLyric, "Line two")
        compare(Services.NeteaseWebLyricsService.currentTranslatedLyric, "第二行")
    }

    function test_stale_silence_still_clears_stopped_session() {
        resetState()

        Services.NeteaseWebLyricsService._applyPayload({
            songId: "8",
            title: "Song",
            artist: "Artist",
            playbackState: "stopped",
            positionMs: 1200,
            durationMs: 5000,
            rawLyric: "[00:00.00]Line one"
        })

        Services.NeteaseWebLyricsService._lastUpdateMs = Date.now() - 60000
        Services.NeteaseWebLyricsService._clearIfStale()

        compare(Services.NeteaseWebLyricsService.songId, "")
        compare(Services.NeteaseWebLyricsService.currentLyric, "")
    }

    function test_compact_translated_line_survives_transient_service_gap() {
        resetState()

        Services.NeteaseWebLyricsService.title = "Song"
        Services.NeteaseWebLyricsService.artist = "Artist"
        Services.NeteaseWebLyricsService.currentLyric = "Line one"
        Services.NeteaseWebLyricsService.currentTranslatedLyric = "第一行"
        Services.NeteaseWebLyricsService.nextLyric = "Line two"
        Services.NeteaseWebLyricsService.nextTranslatedLyric = "第二行"
        Services.NeteaseWebLyricsService.hasLyrics = true
        Services.MediaControlService._refreshLyricsSession()

        tryVerify(function() {
            return Services.MediaControlService.compactPrimaryLyric === "第一行"
                && Services.MediaControlService.compactTranslatedLyric === "第一行"
        }, 1000)

        // Transient gap in the service's translated value must not drop the
        // displayed translation back to the original line.
        Services.NeteaseWebLyricsService.currentTranslatedLyric = ""

        tryVerify(function() {
            return Services.MediaControlService.compactTranslatedLyric === "第一行"
                && Services.MediaControlService.compactOriginalLyric === "Line one"
        }, 1000)
        compare(Services.MediaControlService.showCompactLyric, true)
    }
}
