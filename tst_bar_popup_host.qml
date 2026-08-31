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
    property var _contextCallbackArgs: []

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
        id: openHoverContextReplacementWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("open hover-to-context replacement applies latest current", host.currentIntent.widgetId, "context-open")
            root.check("open hover-to-context replacement clears pending", host.pendingIntent, null)
            root.check("open hover-to-context replacement keeps host open", host.open, true)
            root._contextCallbackArgs = []
            host.contextActions.invoke("moveLeft")
            root.check("open hover-to-context callback receives latest instance key",
                root._contextCallbackArgs[0], "context-open:4")
            root.check("open hover-to-context callback receives latest widget id",
                root._contextCallbackArgs[1], "context-open")
            root.check("open hover-to-context callback receives latest section",
                root._contextCallbackArgs[2], "center")

            // Continue the existing hover bridge close scenario after the
            // direct replacement has completed.
            host.widgetHovered = false
            host.popupHovered = true
            host.requestClose()
            remainOpenWait.restart()
        }
    }

    Timer {
        id: closeWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("close after both hovers released", host.open, false)
            root.check("close timer has fired", host.closeTimerRunning, false)
            root.check("exit cleanup timer is running", host.debugSnapshot().host.clearTimer, true)
            root.check("close intermediate state keeps current intent", host.currentIntent.widgetId, "context-open")
            root.check("close intermediate state keeps root intent", host.intent.widgetId, "context-open")
            root.check("close intermediate state keeps popup owner", host.popupItem !== null, true)
            root.check("close intermediate state keeps surface active", host.surfaceActive, true)
            exitMotionProbe.restart()
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
            root.check("reopen restores content opacity", host.contentOpacity, 1)
            root.check("reopen direction is down", host.direction, "down")
            root.check("TwoLayerPopup direction Down after race reopen", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Down)
            raceWait.restart()
        }
    }

    Timer {
        id: exitMotionProbe
        interval: Math.max(20, Lazer.MotionTokens.fast)
        onTriggered: {
            root.check("exit midpoint keeps popup visible", host.popupItem.visible, true)
            root.check("exit midpoint keeps surface active", host.surfaceActive, true)
            root.check("exit midpoint keeps popup content", host.popupItem.contentLayer.height > 0, true)
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
            // The exit reveal must retain the old content until cleanup.
            host.widgetHovered = false
            host.popupHovered = false
            host.requestClose()
            root.check("close request retains current intent", host.currentIntent.widgetId, "media")
            root.check("close request retains root intent", host.intent.widgetId, "media")
            var popupOwner = host.popupItem
            root.check("close request keeps popup owner", host.popupItem === popupOwner, true)
            host.updateIntent({
                widgetId: "context-reopen", instanceKey: "context-reopen:0", kind: "context",
                actionKind: "", section: "right", hasSettings: false,
                anchorX: 320, screenWidth: 1000, barPosition: "top",
                payload: {
                    moveLeft: function(key, id, section) {
                        root._contextCallbackArgs = [key, id, section]
                    }
                }
            })
            root.check("reopen cancels pending close", host.closeTimerRunning, false)
            root.check("reopen during close keeps same popup owner", host.popupItem === popupOwner, true)
            root.check("reopen replaces latest intent", host.intent.widgetId, "context-reopen")
            contextReopenCallbackWait.restart()
        }
    }

    Timer {
        id: contextReopenCallbackWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root._contextCallbackArgs = []
            host.contextActions.invoke("moveLeft")
            root.check("hover-to-context reopen callback receives latest instance key",
                root._contextCallbackArgs[0], "context-reopen:0")
            root.check("hover-to-context reopen callback receives latest widget id",
                root._contextCallbackArgs[1], "context-reopen")
            root.check("hover-to-context reopen callback receives latest section",
                root._contextCallbackArgs[2], "right")
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
                payload: {
                    moveLeft: function(key, id, section) {
                        root._contextCallbackArgs = [key, id, section]
                    }
                },
                anchorX: 300,
                screenWidth: 1000,
                barPosition: "top"
            }
            host.showIntent(contextIntent)
             root.check("context popup stays visible", host.popupItem.visible, true)
             root.check("context content height positive", host.popupItem.contentLayer.height > 0, true)
             fadeMidWait.restart()
         }
     }

    Timer {
        id: fadeMidWait
        interval: Math.max(20, Lazer.MotionTokens.fast / 2)
        onTriggered: {
            root.check("fade-out keeps current context-reopen intent",
                host.currentIntent.widgetId, "context-reopen")
            root.check("fade-out keeps pending context", host.pendingIntent.kind, "context")
            root.check("fade-out is visibly in progress", host.contentOpacity < 1, true)
            root.check("fade-out keeps old visible context content",
                host.popupItem.contentLayer.children[0].children[1].actionKind, "context")
            root.check("fade-out disables content interaction", host.contentInteractive, false)
            host.updateIntent({
                widgetId: "clock-latest", instanceKey: "clock-latest:0", kind: "context",
                anchorX: 320, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top",
                section: "left", hasSettings: true,
                payload: {
                    moveRight: function(key, id, section) {
                        root._contextCallbackArgs = [key, id, section]
                    }
                }
            })
            root.check("rapid fade replacement keeps latest pending", host.pendingIntent.widgetId,
                "clock-latest")
            fadeCompleteWait.restart()
        }
    }

    Timer {
        id: fadeCompleteWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("fade-out completion applies latest pending",
                host.currentIntent.widgetId, "clock-latest")
            root.check("pending intent clears after apply", host.pendingIntent, null)
            root._contextCallbackArgs = []
            host.contextActions.invoke("moveRight")
            root.check("hover-to-context callback receives latest instance key",
                root._contextCallbackArgs[0], "clock-latest:0")
            root.check("hover-to-context callback receives latest widget id",
                root._contextCallbackArgs[1], "clock-latest")
            root.check("hover-to-context callback receives latest section",
                root._contextCallbackArgs[2], "left")
            fadeInWait.restart()
        }
    }

    Timer {
        id: fadeInWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("fade-in restores opacity", host.contentOpacity, 1)
            root.check("fade-in restores interaction", host.contentInteractive, true)
            root.check("contentFade completion leaves latest current intent",
                host.currentIntent.widgetId, "clock-latest")
            // Context-to-context replacement must keep callbacks bound to the
            // latest payload while the popup object is reused.
            root._contextCallbackArgs = []
            host.contextActions.invoke("moveRight")
            root.check("latest context callback receives instance key",
                root._contextCallbackArgs[0], "clock-latest:0")
            root.check("latest context callback receives widget id",
                root._contextCallbackArgs[1], "clock-latest")
            root.check("latest context callback receives section",
                root._contextCallbackArgs[2], "left")
             host.contextActions.invoke("close")
             root.check("context close dismisses reused host", host.open, false)
             root.check("context close clears current intent immediately", host.currentIntent, null)
             root.check("context close clears root intent immediately", host.intent, null)
             root.check("context close clears pending immediately", host.pendingIntent, null)
             root.check("context close clears surface immediately", host.surfaceActive, false)
             root.check("context close clears replacing immediately", host.replacingContent, false)
             root.check("context close restores opacity immediately", host.contentOpacity, 1)
             root.check("context close stops close timer", host.closeTimerRunning, false)
             root.check("context close stops clear timer", host.debugSnapshot().host.clearTimer, false)

            host.showIntent({
                widgetId: "dismiss-source", instanceKey: "dismiss-source:0", kind: "hover",
                actionKind: "volume", anchorX: 420, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            host.updateIntent({
                widgetId: "dismissed", instanceKey: "dismissed:0", kind: "hover",
                actionKind: "volume", anchorX: 460, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            dismissDuringFadeWait.restart()
        }
    }

    Timer {
        id: dismissDuringFadeWait
        interval: Math.max(20, Lazer.MotionTokens.fast / 2)
        onTriggered: {
            root.check("dismiss test enters replacement fade", host.replacingContent, true)
            root.check("dismiss test has pending intent", host.pendingIntent.widgetId, "dismissed")
            host.dismissImmediately()
            root.check("dismiss during fade clears pending", host.pendingIntent, null)
            root.check("dismiss during fade clears replacing state", host.replacingContent, false)
            root.check("dismiss during fade restores opacity", host.contentOpacity, 1)

            host.showIntent({
                widgetId: "after-dismiss", instanceKey: "after-dismiss:0", kind: "context",
                anchorX: 540, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top"
            })
            root.check("new intent applies after dismiss", host.currentIntent.widgetId, "after-dismiss")
            dismissStaleFadeWait.restart()
        }
    }

    Timer {
        id: dismissStaleFadeWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("dismissed fade cannot overwrite new current intent",
                host.currentIntent.widgetId, "after-dismiss")
            root.check("dismissed fade cannot overwrite new intent",
                host.intent.widgetId, "after-dismiss")
            root.check("dismissed fade leaves pending clear", host.pendingIntent, null)
            root.check("dismissed fade leaves opacity restored", host.contentOpacity, 1)

            Lazer.MotionTokens.reducedMotionOverride = true
            host.updateIntent({
                widgetId: "volume", instanceKey: "volume:reduced", kind: "hover",
                actionKind: "volume", anchorX: 300, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            root.check("reduced motion applies replacement immediately",
                host.currentIntent.widgetId, "volume")
            root.check("reduced motion clears pending intent", host.pendingIntent, null)
            root.check("reduced motion restores content opacity", host.contentOpacity, 1)
            reducedMotionSettleWait.restart()
        }
    }

    Timer {
        id: reducedMotionSettleWait
        interval: host.popupItem.revealDuration + 40
        onTriggered: {
            root.check("reduced motion replacement is interactive", host.contentInteractive, true)
            Lazer.MotionTokens.reducedMotionOverride = false
            host.widgetHovered = false
            host.popupHovered = false
            host.requestClose()
            finalCleanupWait.restart()
        }
    }

    Timer {
        id: finalCleanupWait
        interval: host.popupItem.revealDuration + Lazer.MotionTokens.fast + 120
        onTriggered: {
            root.check("natural close clears current intent", host.currentIntent, null)
            root.check("natural close clears root intent", host.intent, null)
            root.check("natural close is closed", host.open, false)
            root.check("natural close cleanup timer is stopped", host.debugSnapshot().host.clearTimer, false)
            root.check("natural close clears surface active", host.surfaceActive, false)
            root.check("natural close clears pending intent", host.pendingIntent, null)
            root.check("natural close clears replacing state", host.replacingContent, false)
            root.check("natural close restores content opacity", host.contentOpacity, 1)
            root.check("natural close timer is stopped", host.closeTimerRunning, false)
            root.check("natural close leaves popup owner available", host.popupItem !== null, true)
            // Start a replacement, then naturally close while its fade-out is
            // active. The pending target must never be installed during exit.
            host.showIntent({
                widgetId: "race-a", instanceKey: "race-a:0", kind: "hover",
                actionKind: "volume", anchorX: 260, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            host.updateIntent({
                widgetId: "race-b", instanceKey: "race-b:0", kind: "context",
                actionKind: "", anchorX: 720, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            root.check("close race starts replacement", host.replacingContent, true)
            root.check("close race records pending B", host.pendingIntent.widgetId, "race-b")
            host.widgetHovered = false
            host.popupHovered = false
            host.requestClose()
            root.check("close race invalidates replacement immediately", host.replacingContent, false)
            root.check("close race clears pending immediately", host.pendingIntent, null)
            root.check("close race keeps displayed A immediately", host.currentIntent.widgetId, "race-a")
            closeDuringReplacementWait.restart()
        }
    }

    Timer {
        id: closeDuringReplacementWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("close race closes before replacement applies", host.open, false)
            root.check("close race keeps displayed A after fade settles",
                host.currentIntent.widgetId, "race-a")
            root.check("close race retains root intent during exit", host.intent.widgetId, "race-b")
            root.check("close race clears pending replacement", host.pendingIntent, null)
            root.check("close race stops content fade state", host.replacingContent, false)
            root.check("close race restores old content opacity", host.contentOpacity, 1)
            root.check("close race starts exit cleanup", host.debugSnapshot().host.clearTimer, true)
            closeRaceCleanupWait.restart()
        }
    }

    Timer {
        id: closeRaceCleanupWait
        interval: host.popupItem.revealDuration + Lazer.MotionTokens.fast + 120
        onTriggered: {
            root.check("close race cleanup clears current intent", host.currentIntent, null)
            root.check("close race cleanup clears root intent", host.intent, null)
            root.check("close race cleanup clears surface", host.surfaceActive, false)
            root.check("close race cleanup stops timer", host.debugSnapshot().host.clearTimer, false)
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
            root.check("popup exit does not self-clip vertical layers", host.popupItem.clip, false)
            // Slide contract: layers travel the full container distance behind
            // the bar clip edge instead of relying on the opacity channel.
             root.check("identity layer slides from behind bar", host.popupItem.sidebarOffset !== 0, true)
             root.check("content layer shares slide offset", host.popupItem.contentOffset, host.popupItem.sidebarOffset)
             root.check("reveal is geometric (opacity channel off)", host.popupItem.animateLayerOpacity, false)
             root.check("reveal state is active while open",
                 host.surfaceActive && host.popupItem.visible, true)
             root.check("reveal viewport covers complete target",
                 host.popupItem.height >= host.targetHeight, true)
              root.check("content surface paints settings section color",
                 String(host.popupItem.contentLayer.children[0].children[0].objectName) + ":"
                 + String(host.popupItem.contentLayer.children[0].children[0].color),
                 "popupContentSurface:" + String(Lazer.LazerTheme.settingsSection))
              root.check("sidebarData alias exists", host.sidebarData !== undefined, true)
              root.check("contentData alias exists", host.contentData !== undefined, true)

              var outerWidth = host.width
              var outerHeight = host.height
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
                root.check("initial open initializes current intent", host.currentIntent.widgetId, "volume")
                var firstTargetX = host.targetX
                root.check("first intent has distinct target geometry", firstTargetX !== host.displayX, true)
                var hoverSlotHeight = host.popupHeightForIntent(host.currentIntent)
                root.check("hover height selects hover implicit height", host.targetHeight, 89)
                host.updateIntent(contextIntent)
               root.check("second intent changes target geometry", host.targetX !== firstTargetX, true)
               root.check("second intent target follows second anchor", host.targetX,
                   700 - host.targetWidth / 2)
               root.check("display geometry remains separate while animating",
                   host.displayX !== host.targetX || host.displayY !== host.targetY
                   || host.displayWidth !== host.targetWidth || host.displayHeight !== host.targetHeight,
                   true)
               root.check("outer host width stays fixed", host.width, outerWidth)
               root.check("outer host height stays fixed", host.height, outerHeight)
               root.check("replacement keeps host open", host.open, true)
              root.check("replacement keeps surface active", host.surfaceActive, true)
              root.check("replacement exposes latest intent", host.intent.widgetId, "notifications")
              root.check("replacement keeps current intent", host.currentIntent.widgetId, "volume")
               root.check("replacement keeps original popup owner", host.popupItem === originalPopupItem, true)
               root.check("replacement records pending intent", host.pendingIntent.widgetId, "notifications")
                root.check("replacement keeps slot height for current kind",
                    host.popupHeightForIntent(host.currentIntent), hoverSlotHeight)
                root.check("replacement increments transition serial", host.transitionSerial > 0, true)
                 root.check("replacement enters serialized fade", host.replacingContent, true)
                 root.check("replacement target remains screen-clamped", host.targetX >= 8 && host.targetX <= 1000 - host.targetWidth - 8, true)
                 root.check("replacement target keeps current kind height", host.targetHeight, 89)

               host.updateIntent({
                   widgetId: "brightness", instanceKey: "brightness:0", kind: "hover",
                   actionKind: "brightness", anchorX: 520, screenWidth: 1000,
                   screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
               })
               root.check("rapid replacement keeps latest pending target",
                   host.pendingIntent.widgetId, "brightness")

              // Invalid geometry fields must retain the host's last valid values.
              var invalidIntent = {
                  widgetId: "invalid", instanceKey: "invalid:0", kind: "hover",
                  anchorX: "not-a-number", screenWidth: 1000, screenHeight: 800,
                  effectiveBarHeight: 48, barPosition: "sideways"
              }
              host.updateIntent(invalidIntent)
               root.check("invalid anchor keeps host anchor", host.anchorX, 520)
              root.check("invalid bar position keeps host direction", host.direction, "down")
               root.check("invalid anchor geometry uses fallback", host.targetX, 390)

               host.dismissImmediately()
               root.check("dismissImmediately closes host", host.open, false)
               root.check("dismissImmediately clears surface", host.surfaceActive, false)
               root.check("dismissImmediately clears current intent immediately", host.currentIntent, null)
               root.check("dismissImmediately clears root intent immediately", host.intent, null)
               root.check("dismissImmediately clears pending immediately", host.pendingIntent, null)
               root.check("dismissImmediately stops close timer", host.closeTimerRunning, false)
               root.check("dismissImmediately clears replacing immediately", host.replacingContent, false)
               root.check("dismissImmediately restores opacity immediately", host.contentOpacity, 1)
               root.check("dismissImmediately stops clear timer", host.debugSnapshot().host.clearTimer, false)

              host.showIntent(contextIntent)
              Qt.callLater(function () {
                 root.check("context open initializes current intent", host.currentIntent.kind, "context")
                  root.check("context height selects context implicit height",
                      host.popupHeightForIntent(host.currentIntent), 184)
                  root.check("context target follows context height", host.targetHeight, 185)
                  root.startBottomBarChecks()
              })
        })
    }

    function startBottomBarChecks() {
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
          Lazer.MotionTokens.reducedMotionOverride = true
          host.showIntent(intentBottom)
          Lazer.MotionTokens.reducedMotionOverride = false

         Qt.callLater(function () {
                root.check("bottom bar direction is up", host.direction, "up")
                root.check("TwoLayerPopup direction Up for bottom bar", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Up)
                root.check("still open after intent swap", host.open, true)
                 root.check("orientation is Vertical", host.popupItem.orientation, Lazer.TwoLayerPopup.Orientation.Vertical)
                 root.check("bottom geometry stays above bar", host.targetY,
                      Math.max(0, 1080 - 48 - 4 - host.targetHeight))
                 root.check("bottom geometry clamps at screen edge", host.targetY >= 0, true)

                 // Make the displayed height intentionally stale to prove the
                 // bottom placement uses the newly computed target height.
                 host.displayHeight = 7
                 root.check("display height is stale before bottom retarget", host.displayHeight !== host.targetHeight, true)
                 host.updateIntent({
                     widgetId: "tray", instanceKey: "tray:3", kind: "hover", actionKind: "tray",
                     anchorX: 200, screenWidth: 1000, screenHeight: 1080, effectiveBarHeight: 48,
                     barPosition: "bottom"
                 })
                 root.check("bottom target Y uses target height", host.targetY,
                     1080 - 48 - 4 - host.targetHeight)
                 root.check("bottom target Y ignores displayed height", host.targetY !==
                     1080 - 48 - 4 - host.displayHeight, true)

                 // Reduced motion must stop an in-flight retarget before
                 // applying the new geometry, so no old animation can overwrite it.
                 Lazer.MotionTokens.reducedMotionOverride = true
                 host.displayX = 12
                 host.displayY = 13
                 host.displayWidth = 240
                 host.displayHeight = 7
                 host.targetWidth = 260
                 host.targetHeight = 90
                 host.retargetGeometry({ anchorX: 640, screenWidth: 1000,
                     screenHeight: 1080, effectiveBarHeight: 48,
                     floatingMargin: 4, barPosition: "bottom" })
                 root.check("reduced motion settles display X", host.displayX, host.targetX)
                 root.check("reduced motion settles display Y", host.displayY, host.targetY)
                 root.check("reduced motion settles display width", host.displayWidth, host.targetWidth)
                 root.check("reduced motion settles display height", host.displayHeight, host.targetHeight)
                 Lazer.MotionTokens.reducedMotionOverride = false

                  // A live hover intent can be replaced directly by context
                  // without closing or replacing the popup owner.
                  var openHoverPopupOwner = host.popupItem
                  host.updateIntent({
                      widgetId: "context-open", instanceKey: "context-open:4", kind: "context",
                      actionKind: "", anchorX: 260, screenWidth: 1000, screenHeight: 1080,
                      effectiveBarHeight: 48, barPosition: "bottom", section: "center",
                      hasSettings: false,
                      payload: {
                          moveLeft: function(key, id, section) {
                              root._contextCallbackArgs = [key, id, section]
                          }
                      }
                  })
                  root.check("open hover-to-context replacement keeps host open", host.open, true)
                  root.check("open hover-to-context replacement keeps popup owner",
                      host.popupItem === openHoverPopupOwner, true)
                  root.check("open hover-to-context replacement keeps hover current",
                      host.currentIntent.widgetId, "tray")
                  root.check("open hover-to-context replacement records context pending",
                      host.pendingIntent.widgetId, "context-open")
                  root.check("open hover-to-context replacement records latest root intent",
                      host.intent.instanceKey, "context-open:4")
                  openHoverContextReplacementWait.restart()
         })
    }
}
