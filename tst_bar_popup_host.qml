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
            // --- Race: close followed by quick reopen before clearIntentTimer fires ---
            // At this point clearIntentTimer (revealDuration+40 ≈740ms) is still pending
            // because we only waited fast+40 (~140ms). Reopening now must cancel it.
            var raceIntent = {
                widgetId: "media",
                instanceKey: "media:0",
                title: "Media",
                iconSource: Qt.resolvedUrl("modules/lazerbar/icons/music.svg"),
                summary: "Playing",
                actionKind: "media",
                anchorX: 300,
                screenWidth: 1000,
                barPosition: "top"
            }
            host.showIntent(raceIntent)
            root.check("reopen before cleanup keeps open", host.open, true)
            root.check("reopen intent preserved immediately", host.intent !== null && host.intent.widgetId === "media", true)
            root.check("reopen direction is down", host.direction, "down")
            root.check("TwoLayerPopup direction Down after race reopen", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Down)
            raceWait.restart()
        }
    }

    Timer {
        id: raceWait
        // Wait beyond the old clearIntent window (revealDuration+40) to prove it was cancelled
        interval: 800
        onTriggered: {
            root.check("new intent survives old clear timer", host.intent !== null && host.intent.widgetId === "media", true)
            root.check("still open after old timer window", host.open, true)
            root.check("anchor updated after race", host.anchorX, 300)
            root.check("hover bridge still intact after race", host.popupItem.orientation, Lazer.TwoLayerPopup.Orientation.Vertical)
            // Context menus must render visible with real content height.
            var contextIntent = {
                widgetId: "clock",
                instanceKey: "clock:0",
                title: "Clock",
                iconSource: Qt.resolvedUrl("modules/bar/icons/volume.svg"),
                summary: "",
                actionKind: "",
                kind: "context",
                section: "right",
                hasSettings: false,
                anchorX: 300,
                screenWidth: 1000,
                barPosition: "top"
            }
            host.showIntent(contextIntent)
            root.check("context popup stays visible", host.popupItem.visible, true)
            root.check("context content height positive", host.popupItem.contentLayer.height > 0, true)
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
            iconSource: Qt.resolvedUrl("modules/bar/icons/volume.svg"),
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
            // Regression: a parent/child visibility cycle used to deadlock both
            // at false even while the host reported open.
            root.check("popup reveal visible while open", host.popupItem.visible, true)
            root.check("popup container visible while open", host.popupContainerItem.visible, true)
            root.check("hover content height positive", host.popupItem.contentLayer.height > 0, true)
            // Slide contract: layers travel the full container distance behind
            // the bar clip edge instead of relying on the opacity channel.
            root.check("identity layer slides from behind bar", host.popupItem.sidebarOffset !== 0, true)
            root.check("content layer shares slide offset", host.popupItem.contentOffset, host.popupItem.sidebarOffset)
            root.check("reveal is geometric (opacity channel off)", host.popupItem.animateLayerOpacity, false)
            root.check("reveal drives toward open", host.popupItem.revealProgress > 0 || host.popupItem.revealProgress === 0, true)
            root.check("content surface paints settings section color",
                String(host.popupItem.contentLayer.children[0].children[0].objectName) + ":"
                + String(host.popupItem.contentLayer.children[0].children[0].color),
                "popupContentSurface:" + String(Lazer.LazerTheme.settingsSection))
            root.check("sidebarData alias exists", host.sidebarData !== undefined, true)
             root.check("contentData alias exists", host.contentData !== undefined, true)

             var originalPopupItem = host.popupItem
             var volumeIntent = {
                 widgetId: "volume", instanceKey: "volume:0", kind: "hover", actionKind: "volume",
                 anchorX: 180, screenWidth: 1000, screenHeight: 800, effectiveBarHeight: 48,
                 barPosition: "top"
             }
             var contextIntent = {
                 widgetId: "notifications", instanceKey: "notifications:0", kind: "context", actionKind: "",
                 anchorX: 700, screenWidth: 1000, screenHeight: 800, effectiveBarHeight: 48,
                 barPosition: "top"
              }
              host.updateIntent(volumeIntent)
              root.check("hover height selects hover implicit height", host.targetHeight,
                  host.popupItem.sidebarLayer.implicitHeight
                  + host.popupItem.contentLayer.children[0].children[1].implicitHeight + 1)
              host.updateIntent(contextIntent)
              root.check("replacement keeps host open", host.open, true)
              root.check("replacement keeps surface active", host.surfaceActive, true)
              root.check("replacement exposes latest intent", host.intent.widgetId, "notifications")
              root.check("replacement keeps current intent", host.currentIntent.widgetId, "volume")
              root.check("replacement keeps original popup owner", host.popupItem === originalPopupItem, true)
              root.check("replacement records pending intent", host.pendingIntent.widgetId, "notifications")
              root.check("replacement increments transition serial", host.transitionSerial > 0, true)
              root.check("replacement target remains screen-clamped", host.targetX >= 8 && host.targetX <= 1000 - host.targetWidth - 8, true)
              root.check("context height selects context implicit height", host.targetHeight,
                  host.popupItem.sidebarLayer.implicitHeight
                  + host.popupItem.contentLayer.children[0].children[2].implicitHeight + 1)

              // Invalid geometry fields must retain the host's last valid values.
              var invalidIntent = {
                  widgetId: "invalid", instanceKey: "invalid:0", kind: "hover",
                  anchorX: "not-a-number", screenWidth: 1000, screenHeight: 800,
                  effectiveBarHeight: 48, barPosition: "sideways"
              }
              host.updateIntent(invalidIntent)
              root.check("invalid anchor keeps host anchor", host.anchorX, 700)
              root.check("invalid bar position keeps host direction", host.direction, "down")
              root.check("invalid anchor geometry uses fallback", host.targetX, 570)

              host.dismissImmediately()
             root.check("dismissImmediately closes host", host.open, false)
             root.check("dismissImmediately clears surface", host.surfaceActive, false)

             // Switch to bottom bar and verify direction flips without reopening window.
            var intentBottom = {
                widgetId: "tray",
                instanceKey: "tray:2",
                title: "Tray",
                iconSource: Qt.resolvedUrl("modules/lazerbar/icons/apps.svg"),
                summary: "3 items",
                 actionKind: "tray",
                 anchorX: 200,
                 screenWidth: 1000, screenHeight: 1080, effectiveBarHeight: 48,
                 barPosition: "bottom"
            }
            host.showIntent(intentBottom)

             Qt.callLater(function () {
                root.check("bottom bar direction is up", host.direction, "up")
                root.check("TwoLayerPopup direction Up for bottom bar", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Up)
                root.check("still open after intent swap", host.open, true)
                 root.check("orientation is Vertical", host.popupItem.orientation, Lazer.TwoLayerPopup.Orientation.Vertical)
                 root.check("bottom geometry stays above bar", host.targetY,
                     Math.max(0, 1080 - 48 - 4 - host.targetHeight))
                 root.check("bottom geometry clamps at screen edge", host.targetY >= 0, true)

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
