import QtQuick
import Quickshell
import "services" as Services

// Throwaway feedback loop for the per-char lyric transition bug.
// Lives at the repo root so every relative import resolves like production.
// Run: timeout 25 qs -p harness_media_char.qml
// Verdicts: [DEBUG-mce2] VERDICT <tag> PASS|FAIL in the qs log; any FAIL = red.
Item {
    id: root

    property var pill: loader.item ? loader.item.pill : null

    Loader {
        id: loader
        source: "modules/bar/widgets/_mce_harness.qml"
    }

    function findStuck(item, acc) {
        if (!item)
            return acc
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var child = kids[i]
            if (child.visible && child.opacity < 0.05 && child.hasOwnProperty("text") && child.text !== "")
                acc.push(child)
            findStuck(child, acc)
        }
        return acc
    }

    function report(tag) {
        var stuck = root.pill ? findStuck(root.pill, []) : []
        for (var i = 0; i < stuck.length; i++)
            console.log("[DEBUG-mce2]", tag, "stuck text:", JSON.stringify(stuck[i].text), "op:", stuck[i].opacity)
        console.log("[DEBUG-mce2] VERDICT", tag, (root.pill !== null && stuck.length === 0) ? "PASS" : "FAIL")
    }

    Component.onCompleted: {
        Services.SettingsService.ensureWidgetSettings("media", "tst")
        Services.NeteaseWebLyricsService._resetState()
        Services.MediaControlService._resetLyricsLatch()
        Services.NeteaseWebLyricsService.hasLyrics = true
        Services.NeteaseWebLyricsService.currentLyric = "First line"
        seq.restart()
        guard.start()
    }

    Timer {
        id: seq
        interval: 130
        repeat: true
        property int n: 0
        onTriggered: {
            n += 1
            // Alternate short / marquee-triggering long / translated-style lines
            if (n % 3 === 0)
                Services.NeteaseWebLyricsService.currentLyric = "这是一句非常非常长的歌词行用来触发跑马灯滚动效果第" + n + "行"
            else if (n % 3 === 1)
                Services.NeteaseWebLyricsService.currentLyric = "Short " + n
            else
                Services.NeteaseWebLyricsService.currentLyric = "Mixed 中英混排 lyric line number " + n
            if (n >= 20) {
                stop()
                settleTimer.restart()
            }
        }
    }

    Timer {
        id: settleTimer
        interval: 3200
        onTriggered: {
            root.report("rapid20")
            Services.NeteaseWebLyricsService.currentLyric = "Final single line"
            finalTimer.restart()
        }
    }

    Timer {
        id: finalTimer
        interval: 3200
        onTriggered: {
            root.report("single")
            Qt.quit()
        }
    }

    Timer {
        id: guard
        interval: 20000
        onTriggered: {
            Qt.quit()
        }
    }
}
