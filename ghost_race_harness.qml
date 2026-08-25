import QtQuick
import "modules/lazerbar" as Lazer
import "modules/lazerbar/textdiff.js" as TextDiff

// [DEBUG-gx7] Feedback loop for stacked/simultaneous falling-ghost report.
Item {
    id: harn
    width: 400
    height: 200

    Lazer.OsuTextField {
        id: field
        anchors.centerIn: parent
        width: 240
        height: 38
        font.pixelSize: 13
        text: ""
    }

    property int failures: 0
    function fail(msg) { failures++; console.log("[DEBUG-gx7] FAIL:", msg) }
    function pass(name) { console.log("[DEBUG-gx7] PASS:", name) }

    Component.onCompleted: probeA()

    // Symptom A: bulk-delete stagger must stay perceptible per glyph.
    function probeA() {
        var n = 17
        var minGap = 999
        for (var i = 0; i < n - 1; i++) {
            var gap = TextDiff.staggerDelayMs(i, n, 24, 120)
                      - TextDiff.staggerDelayMs(i + 1, n, 24, 120)
            minGap = Math.min(minGap, gap)
        }
        if (minGap >= 16)
            pass("probeA bulkStaggerPerceptible minGap=" + minGap + "ms")
        else
            fail("bulk stagger collapsed to " + minGap + "ms/glyph (<16 reads simultaneous)")
        probeB1()
    }

    // Symptom B: a fresh bulk edit must sweep ghosts still airborne from
    // the previous edit so generations never stack.
    function probeB1() {
        field.suppressDeleteFx = true
        field.text = "abcdefgh"        // seed without effects
        field.suppressDeleteFx = false
        field.text = "abcdef"          // 2 ghosts spawn
        probeBTimer.restart()          // still within 200ms lifetime
    }
    function probeB2() {
        if (field.ghostCount !== 2)
            return fail("expected 2 airborne after first edit, got " + field.ghostCount)
        field.text = ""                // rapid consecutive switch: 6 more spawn
        // destroy() lands at end of event loop; sample after it settles.
        settleTimer.restart()
        if (harn.failures === 0)
            console.log("[DEBUG-gx7] ALL GREEN")
        else
            console.log("[DEBUG-gx7] RED x" + harn.failures)
        Qt.quit()
    }

    Timer { id: probeBTimer; interval: 60; onTriggered: harn.probeB2() }
    Timer { id: settleTimer; interval: 8; onTriggered: harn.probeB3() }

    function probeB3() {
        var total = field.ghostCount
        if (total > 6)
            fail("generations stacked: " + total + " ghosts airborne (cap 6)")
        else
            pass("probeB3 noGenerationStacking count=" + total)
        if (harn.failures === 0)
            console.log("[DEBUG-gx7] ALL GREEN")
        else
            console.log("[DEBUG-gx7] RED x" + harn.failures)
        Qt.quit()
    }
}
