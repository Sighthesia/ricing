import QtQuick
import QtTest
import "../../modules/bar/widgets/TraySlotLogic.js" as SlotLogic

// Tray slot bookkeeping: stable identity, the model diff that keeps a
// surviving icon's delegate alive, and the enter/exit numbers the text
// transition contributes.
Item {
    TestCase {
        name: "TraySlotLogic"
        id: traySlotCase

        // --- stable identity -------------------------------------------------

        function test_keyPrefersSniId() {
            compare(SlotLogic.slotKey({ id: "org.kde.tray", title: "Mail" }, 3),
                    "org.kde.tray")
        }

        function test_keyFallsBackToTitleThenTooltip() {
            compare(SlotLogic.slotKey({ id: "", title: "Mail" }, 0), "Mail")
            compare(SlotLogic.slotKey({ id: "", title: "", tooltipTitle: "Disk" }, 1), "Disk")
        }

        function test_keyFallsBackToIndex() {
            compare(SlotLogic.slotKey({}, 4), "tray:4")
            compare(SlotLogic.slotKey(null, 2), "tray:2")
        }

        function test_keyIsStableAcrossLabelChanges() {
            var before = SlotLogic.slotKey({ id: "app.tray", title: "One" }, 0)
            var after = SlotLogic.slotKey({ id: "app.tray", title: "Two" }, 0)
            compare(before, after)
        }

        // --- model diff ------------------------------------------------------

        function test_diffReportsArrivalsAndDepartures() {
            var change = SlotLogic.diff(["a", "b", "c"], ["b", "c", "d"])
            compare(change.added, ["d"])
            compare(change.removed, ["a"])
        }

        function test_diffKeepsOrderOfTheIncomingBatch() {
            var change = SlotLogic.diff([], ["a", "b", "c", "d"])
            compare(change.added, ["a", "b", "c", "d"])
            compare(change.removed, [])
        }

        function test_diffOfUnchangedListIsEmpty() {
            var change = SlotLogic.diff(["a", "b"], ["a", "b"])
            compare(change.added.length, 0)
            compare(change.removed.length, 0)
        }

        function test_diffIgnoresReordering() {
            // A reorder is a move, not a churn: no slot may be torn down, or
            // the icons would rebuild and re-request their pixmaps.
            var change = SlotLogic.diff(["a", "b", "c"], ["c", "a", "b"])
            compare(change.added.length, 0)
            compare(change.removed.length, 0)
        }

        function test_diffOfEmptyTray() {
            var change = SlotLogic.diff(["a", "b"], [])
            compare(change.added, [])
            compare(change.removed, ["a", "b"])
        }

        // --- cascade ---------------------------------------------------------

        function test_arrivalsSweepLeftToRight() {
            compare(SlotLogic.cascadeDelayMs(0, 4, 24, false), 0)
            compare(SlotLogic.cascadeDelayMs(1, 4, 24, false), 24)
            compare(SlotLogic.cascadeDelayMs(3, 4, 24, false), 72)
        }

        function test_departuresSweepRightToLeft() {
            // The text contract: the rightmost glyph detaches first.
            compare(SlotLogic.cascadeDelayMs(0, 4, 24, true), 72)
            compare(SlotLogic.cascadeDelayMs(3, 4, 24, true), 0)
        }

        function test_singleSlotIsNeverDelayed() {
            compare(SlotLogic.cascadeDelayMs(0, 1, 24, false), 0)
            compare(SlotLogic.cascadeDelayMs(0, 1, 24, true), 0)
            compare(SlotLogic.cascadeDelayMs(0, 0, 24, true), 0)
        }

        function test_cascadeClampsOutOfRangeIndex() {
            compare(SlotLogic.cascadeDelayMs(9, 3, 24, false), 48)
            compare(SlotLogic.cascadeDelayMs(-4, 3, 24, false), 0)
        }

        function test_cascadeStaysPositive() {
            verify(SlotLogic.cascadeDelayMs(1, 4, 0, false) > 0)
        }

        // --- fall geometry ---------------------------------------------------

        function test_fallStaysInsideTheBarRow() {
            // A drop longer than the gap under a centred glyph would be sliced
            // by the bar's clip, which reads as a cut instead of a fall.
            var widgetHeight = 42
            var glyphSize = 24
            var distance = SlotLogic.fallDistance(widgetHeight, glyphSize)
            compare(distance, (widgetHeight - glyphSize) / 2)
            verify(distance <= (widgetHeight - glyphSize) / 2 + 0.001)
        }

        function test_fallScalesWithBarHeight() {
            verify(SlotLogic.fallDistance(58, 32) > SlotLogic.fallDistance(42, 24))
        }

        function test_fallNeverCollapses() {
            // A glyph filling its slot leaves no room; the fall must still be
            // a real motion rather than a no-op.
            verify(SlotLogic.fallDistance(24, 24) >= 2)
            verify(SlotLogic.fallDistance(10, 24) >= 2)
        }
    }
}
