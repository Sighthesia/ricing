import QtQuick
import Quickshell
import "services" as Services

// Throwaway feedback loop for media pill lyric transitions + marquee.
// Lives at the repo root so every relative import resolves like production.
// Run: scripts/run_mce.sh
// Verdicts: [DEBUG-mce4] VERDICT <tag> PASS|FAIL; any FAIL = red.
Item {
    id: root

    readonly property string finalLine:
        "收尾单独一行超长歌词继续验证跑马灯起点与省略号状态是否正确处理完毕"

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

    // The primary label is the bold-12 Text showing exactly primaryText.
    function findTitle(item, wantText, acc) {
        if (!item)
            return acc
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (c.hasOwnProperty("elide") && c.text === wantText
                    && c.font !== undefined && c.font.bold && c.font.pixelSize === 12)
                acc.push(c)
            findTitle(c, wantText, acc)
        }
        return acc
    }

    function report(tag) {
        var stuck = root.pill ? findStuck(root.pill, []) : []
        for (var i = 0; i < stuck.length; i++)
            console.log("[DEBUG-mce4]", tag, "stuck text:", JSON.stringify(stuck[i].text), "op:", stuck[i].opacity)
        console.log("[DEBUG-mce4] VERDICT", tag, (root.pill !== null && stuck.length === 0) ? "PASS" : "FAIL")
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
            // Back-to-back long lines exercise the marquee restart path.
            Services.NeteaseWebLyricsService.currentLyric =
                "连续两行超长歌词用于验证跑马灯在逐字入场完成后从正确起点滚动第" + n + "次"
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
            Services.NeteaseWebLyricsService.currentLyric = root.finalLine
            marqueeProbe.restart()
        }
    }

    // Sample shortly after reveal completes but inside the marquee's initial
    // 1400ms pause: the label must be fully revealed at x==0, un-elided.
    Timer {
        id: marqueeProbe
        interval: 1300
        onTriggered: {
            var found = findTitle(root.pill, root.finalLine, [])
            if (found.length === 0) {
                console.log("[DEBUG-mce4] VERDICT marquee FAIL (title not found)")
            } else {
                for (var i = 0; i < found.length; i++) {
                    var t = found[i]
                    var okX = Math.abs(t.x) < 0.5
                    var okElide = t.elide === Text.ElideNone
                    console.log("[DEBUG-mce4] title x:", t.x.toFixed(2), "w:", t.width.toFixed(1),
                                "iw:", t.implicitWidth.toFixed(1), "elide:", t.elide, "op:", t.opacity.toFixed(2))
                    console.log("[DEBUG-mce4] VERDICT marquee",
                                (okX && okElide && t.opacity > 0.9) ? "PASS" : "FAIL",
                                "okX:" + okX, "okElide:" + okElide)
                }
            }
            Qt.quit()
        }
    }

    Timer {
        id: guard
        interval: 20000
        onTriggered: {
            console.log("[DEBUG-mce4] VERDICT timeout FAIL")
            Qt.quit()
        }
    }
}
