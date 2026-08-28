import QtQuick
import "modules/bar" as Bar
import "modules/lazerbar" as Lazer

// qs behavior harness for BarPopupHost direction and hover lifecycle.
// Run with: qs -p tst_bar_popup_host.qml
Item {
    id: root
    width: 1
    height: 1

    property int _failures: 0
    property int _checks: 0

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root._failures += 1
        console.log("FAIL:", label, "expected", JSON.stringify(expected), "got", JSON.stringify(actual))
    }

    // Host under test - per-screen fixed popup host.
    Bar.BarPopupHost {
        id: host
        // Use deterministic screenWidth for anchor clamping tests.
        screenWidth: 1000
        effectiveBarHeight: 48
        floatingMargin: 4
        // PanelWindow screen remains null in harness; host falls back to screenWidth.
    }

    // Timers for async close-delay waits.
    Timer {
        id: remainOpenWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("requestClose while popupHovered keeps open", host.open, true)
            // Now release both hovers and expect close.
            host.widgetHovered = false
            host.popupHovered = false
            host.requestClose()
            closeWait.restart()
        }
    }

    Timer {
        id: closeWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("close after both hovers released", host.open, false)
            // Direction enum stays consistent after close (last intent was bottom -> Up)
            root.check("TwoLayerPopup direction Up after bottom bar", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Up)
            console.log("Totals:", (root._checks - root._failures), "passed,", root._failures, "failed")
            Qt.quit()
        }
    }

    Component.onCompleted: Qt.callLater(root.run)

    function run() {
        var intentTop = {
            widgetId: "volume",
            instanceKey: "volume:0",
            title: "Volume",
            iconSource: "icons/volume.svg",
            summary: "45%",
            actionKind: "volume",
            anchorX: 100,
            screenWidth: 1000,
            barPosition: "top"
        }

        host.showIntent(intentTop)
        // Allow one turn for bindings to settle.
        Qt.callLater(function () {
            root.check("showIntent opens host (top)", host.open, true)
            root.check("top bar direction is down", host.direction, "down")
            root.check("TwoLayerPopup direction Down for top bar", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Down)
            root.check("anchorX stored", host.anchorX, 100)
            root.check("screenWidth stored", host.screenWidth, 1000)
            root.check("intent preserved", host.intent !== null && host.intent.widgetId === "volume", true)
            root.check("sidebarData alias exists", host.sidebarData !== undefined, true)
            root.check("contentData alias exists", host.contentData !== undefined, true)

            // Switch to bottom bar and verify direction flips without reopening window.
            var intentBottom = {
                widgetId: "tray",
                instanceKey: "tray:2",
                title: "Tray",
                iconSource: "icons/tray.svg",
                summary: "3 items",
                actionKind: "tray",
                anchorX: 200,
                screenWidth: 1000,
                barPosition: "bottom"
            }
            host.showIntent(intentBottom)

            Qt.callLater(function () {
                root.check("bottom bar direction is up", host.direction, "up")
                root.check("TwoLayerPopup direction Up for bottom bar", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Up)
                root.check("still open after intent swap", host.open, true)
                root.check("orientation is Vertical", host.popupItem.orientation, Lazer.TwoLayerPopup.Orientation.Vertical)

                // Hover bridge: popup hover keeps it alive.
                host.widgetHovered = false
                host.popupHovered = true
                host.requestClose()

                // Wait the close delay; popupHovered true should keep it open.
                remainOpenWait.restart()
            })
        })
    }
}
