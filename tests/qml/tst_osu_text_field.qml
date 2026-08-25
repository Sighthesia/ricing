import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/textdiff.js" as TextDiff

// Contract tests for the osu!lazer text editing feedback: smooth caret and
// falling delete ghosts, plus the pure diff helpers that drive them.
Item {
    width: 400
    height: 200

    Lazer.OsuTextField {
        id: field
        anchors.centerIn: parent
        width: 240
        height: 38
        font.pixelSize: 13
        text: "abcdef"
    }

    TestCase {
        name: "TextDiff"

        function test_noChangeReturnsNull() {
            compare(TextDiff.removeRange("abc", "abc"), null)
        }

        function test_insertionOnlyReturnsNull() {
            compare(TextDiff.removeRange("abc", "abxc"), null)
            compare(TextDiff.removeRange("", "x"), null)
        }

        function test_backspaceRemovesTrailingRun() {
            var range = TextDiff.removeRange("abcd", "abc")
            compare(range.start, 3)
            compare(range.removed, "d")
        }

        function test_forwardDeleteAnchorsAtPrefix() {
            var range = TextDiff.removeRange("abcd", "bcd")
            compare(range.start, 0)
            compare(range.removed, "a")
        }

        function test_middleDeletionKeepsAnchor() {
            var range = TextDiff.removeRange("hello world", "helo world")
            compare(range.start, 3)
            compare(range.removed, "l")
        }

        function test_replacementReportsRemovedPart() {
            var range = TextDiff.removeRange("cat", "cut")
            compare(range.start, 1)
            compare(range.removed, "a")
        }

        function test_clearingEverythingAnchorsAtZero() {
            var range = TextDiff.removeRange("abc", "")
            compare(range.start, 0)
            compare(range.removed, "abc")
        }

        function test_cumulativeOffsetsUseAdvanceWidths() {
            var offsets = TextDiff.cumulativeOffsets("ab", function(ch) { return ch === "a" ? 5 : 7 })
            compare(offsets.length, 2)
            compare(offsets[0], 0)
            compare(offsets[1], 5)
        }

        function test_staggerDelaysRightmostFirst() {
            compare(TextDiff.staggerDelayMs(1, 1, 24, 120), 0)
            compare(TextDiff.staggerDelayMs(1, 2, 24, 120), 0)
            compare(TextDiff.staggerDelayMs(0, 2, 24, 120), 24)
        }

        function test_staggerStepShrinksThenFloors() {
            // Short removals keep the 24ms pace; longer ones shrink toward
            // the perceptible floor instead of collapsing to zero.
            compare(TextDiff.staggerDelayMs(8, 10, 24, 120) - TextDiff.staggerDelayMs(9, 10, 24, 120),
                    Math.floor(120 / 9))
            compare(TextDiff.staggerDelayMs(8, 10, 24, 120), 16 * 2)
        }

        function test_staggerStepFloorsAtPerceptibleMinimum() {
            // Long removals must never compress adjacent delays below ~16ms:
            // the tail of the cascade would read as one simultaneous drop.
            for (var n = 2; n <= 30; n++) {
                var minGap = 999
                for (var i = 0; i < n - 1; i++) {
                    var gap = TextDiff.staggerDelayMs(i, n, 24, 120)
                              - TextDiff.staggerDelayMs(i + 1, n, 24, 120)
                    minGap = Math.min(minGap, gap)
                }
                verify(minGap >= 16, "n=" + n + " collapsed to " + minGap + "ms/glyph")
            }
        }
    }

    TestCase {
        name: "OsuTextFieldEffects"

        function init() {
            tryCompare(field, "ghostCount", 0)
            Lazer.MotionTokens.reducedMotionOverride = false
            field.suppressDeleteFx = false
            field.text = "abcdef"
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
            field.suppressDeleteFx = false
        }

        function test_caretCarriesOsuContracts() {
            var caret = field.caretItem
            verify(caret !== null)
            verify(caret.target === field)
            verify(caret.moveTime === 60)
            verify(caret.blinkHigh === 0.7 && caret.blinkLow === 0.4)
            verify(caret.blinkHalfPeriod === 250)
            verify(caret.width === 3)
            tryCompare(caret, "visualOpacity", 0, 600)
        }

        function test_caretPulsesWhileFocused() {
            var caret = field.caretItem
            field.forceActiveFocus()
            verify(caret.focused)
            // The pulse must dip toward the dim stop and climb back while focused.
            var dipped = false
            tryVerify(function() {
                if (caret.visualOpacity < 0.55)
                    dipped = true
                return dipped && caret.visualOpacity > 0.55
            }, 1500)
            field.focus = false
        }

        function test_caretGlidesTowardCursorMoves() {
            var caret = field.caretItem
            field.forceActiveFocus()
            field.cursorPosition = 0
            tryCompare(caret, "x", field.cursorRectangle.x, 400)
            // Moving the cursor retargets instantly while the Behavior glides.
            field.cursorPosition = field.text.length
            tryVerify(function() { return caret.x > 1 }, 400)
            field.focus = false
        }

        function test_deletionSpawnsFallingGhosts() {
            field.forceActiveFocus()
            field.text = "abcd"
            tryCompare(field, "ghostCount", 2)
            var ghost = field.ghostLayerItem.children[0]
            verify(ghost.y >= 0)
            var startY = ghost.y
            tryCompare(ghost, "opacity", 0, 700)
            tryVerify(function() { return ghost.y > startY }, 700)
            field.focus = false
        }

        function test_ghostPopulationRetires() {
            field.text = "abc"
            tryCompare(field, "ghostCount", 3)
            tryCompare(field, "ghostCount", 0, 900)
        }

        function test_bulkRemovalSweepsAirborneGeneration() {
            // Rapid consecutive edits: a bulk removal must retire ghosts
            // still falling from the previous edit so generations never
            // stack on screen.
            field.suppressDeleteFx = true
            field.text = "abcdefgh"
            field.suppressDeleteFx = false
            field.text = "abcdef"   // 2 ghosts airborne (lifetime 200ms+)
            tryCompare(field, "ghostCount", 2)
            field.text = ""         // bulk removal sweeps them + spawns 8
            tryVerify(function() { return field.ghostCount <= 8 }, 50)
            verify(field.ghostCount === 8,
                   "expected exactly the new generation, got " + field.ghostCount)
        }

        function test_suppressedSyncSpawnsNoGhosts() {
            field.suppressDeleteFx = true
            field.text = "abc"
            compare(field.ghostCount, 0)
            field.text = ""
            compare(field.ghostCount, 0)
        }

        function test_reducedMotionSkipsGhostEffects() {
            Lazer.MotionTokens.reducedMotionOverride = true
            field.text = "abc"
            field.text = "ab"
            compare(field.ghostCount, 0)
        }
    }
}
