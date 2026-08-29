import QtQuick
import QtTest
import "../../modules/bar/BarHoverLogic.js" as Logic

Item {
    TestCase {
        name: "BarHoverLogic"

        function test_topBarOpensDown() {
            compare(Logic.popupDirection("top"), "down")
        }

    function test_bottomBarOpensUp() {
            compare(Logic.popupDirection("bottom"), "up")
        }

        function test_topBarDefaultForUnknownPosition() {
            compare(Logic.popupDirection(""), "down")
            compare(Logic.popupDirection(null), "down")
            compare(Logic.popupDirection("left"), "down")
            compare(Logic.popupDirection(undefined), "down")
        }

        function test_popupDirectionNormalized() {
            compare(Logic.popupDirection(" Bottom "), "up")
            compare(Logic.popupDirection("BOTTOM"), "up")
            compare(Logic.popupDirection(" bottom"), "up")
            compare(Logic.popupDirection(" Top "), "down")
        }

        function test_anchorStaysInsideScreen() {
            compare(Logic.clampAnchor(10, 240, 1000, 12), 12)
            compare(Logic.clampAnchor(900, 240, 1000, 12), 748)
        }

        function test_anchorClampsToZeroWidthSafeOnInvalidNumbers() {
            compare(Logic.clampAnchor(NaN, 240, 1000, 12), 12)
            compare(Logic.clampAnchor(10, NaN, 1000, 12), 12)
            compare(Logic.clampAnchor(10, 240, NaN, 12), 12)
            compare(Logic.clampAnchor(10, 240, 1000, NaN), 10)
            // undefined / null fallback
            compare(Logic.clampAnchor(undefined, 240, 1000, 12), 12)
            compare(Logic.clampAnchor(500, 200, 800, 10), 500)
            compare(Logic.clampAnchor(NaN, NaN, NaN, NaN), 0)
        }

        function test_anchorOverflowClampsToMax() {
            compare(Logic.clampAnchor(0, 900, 800, 10), 10)
            // screen narrower than popup + margins -> clamped to margin
            compare(Logic.clampAnchor(500, 500, 400, 12), 12)
        }

        function test_closeWaitsForBothHoverOwners() {
            verify(!Logic.shouldClose(true, false, true))
            verify(!Logic.shouldClose(false, true, true))
            verify(Logic.shouldClose(false, false, true))
        }

        function test_closeRequiresPending() {
            verify(!Logic.shouldClose(false, false, false))
            verify(!Logic.shouldClose(false, false, null))
            verify(!Logic.shouldClose(false, false, undefined))
            verify(!Logic.shouldClose(true, true, false))
        }

        function test_hoverPayloadReturnsPlainObject() {
            var payload = Logic.hoverPayload("tray", "tray:0", "Tray", "icon.png", "3 items", "tray")
            compare(payload.widgetId, "tray")
            compare(payload.instanceKey, "tray:0")
            compare(payload.title, "Tray")
            compare(payload.iconSource, "icon.png")
            compare(payload.summary, "3 items")
            compare(payload.actionKind, "tray")
            // no QML references, plain data only
            verify(payload !== null && typeof payload === "object")
        }

        function test_hoverPayloadNormalizesFields() {
            var payload = Logic.hoverPayload(null, undefined, 123, null, undefined, null)
            compare(payload.widgetId, "")
            compare(payload.instanceKey, "")
            compare(payload.title, "123")
            compare(payload.iconSource, "")
            compare(payload.summary, "")
            compare(payload.actionKind, "")
        }

        function test_hoverPayloadPreservesActionKinds() {
            var kinds = ["tray", "volume", "brightness", "media", "notifications"]
            for (var i = 0; i < kinds.length; i++) {
                var p = Logic.hoverPayload("id", "id:0", "T", "", "", kinds[i])
                compare(p.actionKind, kinds[i])
            }
        }
    }

    function test_hoverAndContextKindsAreDistinct() {
        compare(Logic.popupKind({ actionKind: "volume" }), "hover")
        compare(Logic.popupKind({ kind: "context" }), "context")
    }

    function test_newIntentReplacesExistingPopup() {
        verify(Logic.canReplace({ actionKind: "volume" }, { kind: "context" }))
        verify(Logic.canReplace({ actionKind: "tray", instanceKey: "tray:0" }, { actionKind: "tray", instanceKey: "tray:1" }))
        verify(!Logic.canReplace({ actionKind: "volume" }, null))
    }

    function test_settingsIntentIsNotBarPopup() {
        verify(Logic.isSettingsIntent({ widgetId: "settings" }))
        verify(!Logic.isSettingsIntent({ widgetId: "volume" }))
    }
}
