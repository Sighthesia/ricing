import QtQuick
import "./services" as Services

// Behavioral checks for lyric session binding and multi-tab arbitration,
// run from the repo root so ./services resolves inside the config folder:
//   qs -p tst_media_binding.qml
Item {
    id: root

    property int _failures: 0
    property int _checks: 0
    property var _steps: []

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root._failures += 1
        console.log("FAIL:", label, "expected", JSON.stringify(expected), "got", JSON.stringify(actual))
    }

    function makePlayer(title, artist) {
        return { identity: "Firefox", desktopEntry: "firefox",
            dbusName: "org.mpris.MediaPlayer.firefox.test", trackTitle: title,
            trackArtist: artist, trackAlbum: "", trackArtUrl: "",
            positionSupported: true, position: 0, lengthSupported: true,
            length: 100, playbackState: 2, isPlaying: true }
    }

    function run() {
        const lyrics = Services.NeteaseWebLyricsService
        const media = Services.MediaService
        const control = Services.MediaControlService

        // --- Binding: suspend on mismatched active player, resume after.
        lyrics._resetState()
        lyrics._applyPayload({ songId: "42", title: "Bound Song", artist: "Bound Artist",
            playbackState: "playing", positionMs: 1000, durationMs: 200000,
            rawLyric: "[00:01.00]Hello line" })
        check("no player -> bound", lyrics.boundToActivePlayer, true)
        check("no player -> line shown", lyrics.currentLyric, "Hello line")

        media._activePlayerRef = makePlayer("Other Song", "Other Artist")
        root._steps.push(function() {
            check("mismatched player -> suspended", lyrics.boundToActivePlayer, false)
            check("suspended hides current line", lyrics.currentLyric, "")
            check("suspended keeps session", lyrics.rawLyric !== "", true)
            check("control service drops lyric source", control._lyricsSignalActive, false)

            media._activePlayerRef = null
            root._steps.push(function() {
                check("player removed -> rebound", lyrics.boundToActivePlayer, true)
                check("rebound restores line", lyrics.currentLyric, "Hello line")

                // --- Arbitration: playing session beats paused other-tab payloads.
                lyrics._resetState()
                media._activePlayerRef = null
                lyrics._applyPayload({ songId: "7", title: "Playing Song", artist: "A",
                    playbackState: "playing", positionMs: 5000, durationMs: 200000 })
                check("arbitration setup playing", lyrics.playbackState, "playing")

                lyrics._applyPayload({ songId: "9", title: "Paused Tab Song", artist: "B",
                    playbackState: "paused", positionMs: 100, durationMs: 200000 })
                check("paused other tab ignored", lyrics.songId, "7")
                check("ignored payload kept title", lyrics.title, "Playing Song")

                lyrics._applyPayload({ songId: "9", title: "Next Playing Song", artist: "B",
                    playbackState: "playing", positionMs: 10, durationMs: 200000 })
                check("newer playing tab takes over", lyrics.songId, "9")

                media._activePlayerRef = null
                lyrics._resetState()
                console.log("Totals:", root._checks - root._failures, "passed,", root._failures, "failed")
                Qt.quit(root._failures === 0 ? 0 : 1)
            })
            Qt.callLater(root._steps.shift())
        })
        Qt.callLater(root._steps.shift())
    }

    Component.onCompleted: Qt.callLater(root.run)
}
