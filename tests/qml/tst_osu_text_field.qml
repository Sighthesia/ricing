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

        function test_staggerTotalIsCapped() {
            // 10 characters: step shrinks so the last delay never exceeds the cap.
            verify(TextDiff.staggerDelayMs(0, 10, 24, 120) <= 120)
            var step = TextDiff.staggerDelayMs(8, 10, 24, 120) - TextDiff.staggerDelayMs(9, 10, 24, 120)
            compare(step, Math.floor(120 / 9))
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

        function instantiateCaret() {
            var caret = field.cursorDelegate.createObject(null, { editor: field })
            verify(caret !== null)
            return caret
        }

        function test_caretDelegateCarriesOsuContracts() {
            verify(field.cursorDelegate !== null)
            var caret = instantiateCaret()
            verify(caret.moveTime === 60)
            verify(caret.blinkHigh === 0.7 && caret.blinkLow === 0.4)
            verify(caret.blinkPeriod === 500)
            verify(caret.fadeTime === 200)
            verify(caret.width === 3)
            verify(!caret.focused)
            tryCompare(caret, "visualOpacity", 0, 600)
            caret.destroy()
        }

        function test_caretPulsesWhileFocused() {
            var caret = instantiateCaret()
            field.forceActiveFocus()
            verify(caret.focused)
            tryCompare(caret, "visualOpacity", 0.7, 100)
            tryVerify(function() { return caret.visualOpacity < 0.7 }, 800)
            field.focus = false
            caret.destroy()
        }

        function test_caretGlidesOnlyAfterFirstPlacement() {
            var caret = instantiateCaret()
            verify(!caret.glideReady)
            caret.x = 42
            tryCompare(caret, "glideReady", true)
            caret.destroy()
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
