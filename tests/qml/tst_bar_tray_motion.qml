import QtQuick
import QtTest
import "../../modules/bar/widgets/TraySlotLogic.js" as SlotLogic

// Tray slot bookkeeping: the per-object identity a slot is filed under, the
// model diff that keeps a surviving icon's delegate alive, and the enter/exit
// numbers the text transition contributes.
Item {
    TestCase {
        name: "TraySlotLogic"

        // Fake tray items. Plain objects stand in for SystemTrayItem: identity
        // is object identity, so the fakes need nothing from the real type.
        property var qq: ({ id: "shared", title: "QQ", tooltipTitle: "shared" })
        property var fcitx: ({ id: "shared", title: "输入法", tooltipTitle: "shared" })
        property var clash: ({ id: "org.kde.clash", title: "Clash", tooltipTitle: "Clash" })

        // --- identity -------------------------------------------------------

        function test_objectsGetDistinctKeys() {
            var registry = SlotLogic.emptyRegistry()
            var keys = SlotLogic.reindex(registry, [qq, fcitx])
            compare(keys.length, 2)
            verify(keys[0] !== keys[1])
        }

        function test_twoItemsSharingOneIdStayApart() {
            // The reported failure: QQ and the input method both report the
            // same `id`. A string key would collapse or swap them.
            var registry = SlotLogic.emptyRegistry()
            var keys = SlotLogic.reindex(registry, [qq, fcitx])
            compare(registry.items[0], qq)
            compare(registry.items[1], fcitx)
        }

        function test_keysSurviveReordering() {
            var registry = SlotLogic.emptyRegistry()
            var before = SlotLogic.reindex(registry, [qq, fcitx])
            var after = SlotLogic.reindex(registry, [fcitx, qq])
            // Same objects, swapped places: each keeps its own key, and the
            // diff reports no churn at all.
            compare(after[0], before[1])
            compare(after[1], before[0])
            var change = SlotLogic.diff(before, after)
            compare(change.added.length, 0)
            compare(change.removed.length, 0)
        }

        function test_keysSurviveARepeatedRefresh() {
            var registry = SlotLogic.emptyRegistry()
            var first = SlotLogic.reindex(registry, [qq, fcitx, clash])
            var second = SlotLogic.reindex(registry, [qq, fcitx, clash])
            compare(second, first)
        }

        function test_departedObjectDropsItsKey() {
            var registry = SlotLogic.emptyRegistry()
            var before = SlotLogic.reindex(registry, [qq, fcitx])
            SlotLogic.reindex(registry, [qq])
            compare(registry.items.length, 1)
            var again = SlotLogic.reindex(registry, [qq, fcitx])
            // fcitx is a new registration as far as the strip is concerned: it
            // must not resurrect the key it held when it left.
            verify(again[1] !== before[1])
        }

        function test_freshKeyIsNotReusedAfterADeparture() {
            var registry = SlotLogic.emptyRegistry()
            var first = SlotLogic.reindex(registry, [qq])
            SlotLogic.reindex(registry, [])
            var second = SlotLogic.reindex(registry, [fcitx])
            verify(second[0] !== first[0])
        }

        function test_nullEntriesAreSkipped() {
            var registry = SlotLogic.emptyRegistry()
            var keys = SlotLogic.reindex(registry, [null, qq, undefined])
            compare(keys.length, 1)
            compare(registry.items[0], qq)
        }

        function test_oneObjectListedTwiceGetsOneSlot() {
            var registry = SlotLogic.emptyRegistry()
            var keys = SlotLogic.reindex(registry, [qq, qq, fcitx])
            compare(keys.length, 2)
            compare(registry.items[1], fcitx)
        }

        function test_emptyListDropsEverything() {
            var registry = SlotLogic.emptyRegistry()
            SlotLogic.reindex(registry, [qq, fcitx])
            var keys = SlotLogic.reindex(registry, [])
            compare(keys.length, 0)
            compare(registry.items.length, 0)
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