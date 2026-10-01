import QtQuick
import "modules/bar" as Bar
import "modules/lazerbar" as Lazer

// qs behavior harness for BarPopupHost opaque 45%-exchange glide contract.
// Run with: qs -p tst_bar_popup_host.qml
Item {
    id: root
    width: 1
    height: 1

    property int _failures: 0
    property int _checks: 0
    property var _contextCallbackArgs: []
    property string _settleLabel: ""
    property var _settleNext: null

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root._failures += 1
        console.log("FAIL:", label, "expected", JSON.stringify(expected), "got", JSON.stringify(actual))
    }

    function checkClose(label, actual, expected, eps) {
        root._checks += 1
        var tol = eps !== undefined ? eps : 1.5
        if (Math.abs(Number(actual) - Number(expected)) <= tol) {
            console.log("PASS:", label)
            return
        }
        root._failures += 1
        console.log("FAIL:", label, "expected ~", JSON.stringify(expected), "got", JSON.stringify(actual))
    }

    function layerOpacity() {
        return {
            "sidebar": Number(host.popupItem.sidebarLayer.opacity),
            "content": Number(host.popupItem.contentLayer.opacity)
        }
    }

    function checkOpaque(label) {
        var op = root.layerOpacity()
        root.check(label + " sidebar opaque", op.sidebar, 1)
        root.check(label + " content opaque", op.content, 1)
    }

    // The geometry glide can be re-armed by a deferred post-exchange rebase that
    // flushes when the reveal finishes, so a single fixed wait no longer
    // guarantees it has settled. Poll for the real resting state.
    property int _settleWaits: 0
    function settleGlideThen(label, next) {
        root._settleWaits += 1
        if (host.transitionProgress >= 0.999 || root._settleWaits > 40) {
            root._settleWaits = 0
            root.check(label, host.transitionProgress, 1)
            if (next)
                next()
            return
        }
        settlePoll.restart()
    }

    Timer {
        id: settlePoll
        interval: 40
        onTriggered: {
            settleGlideThen(root._settleLabel, root._settleNext)
        }
    }

    function findByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var found = findByName(kids[i], name)
            if (found)
                return found
        }
        return null
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
        interval: Lazer.MotionTokens.medium + 150
        onTriggered: {
            root.check("open hover-to-context replacement applies latest current", host.currentIntent.widgetId, "context-open")
            root.check("open hover-to-context replacement clears pending", host.pendingIntent, null)
            root.check("open hover-to-context replacement keeps host open", host.open, true)
            root._settleLabel = "glide settles at progress 1"
            root._settleNext = function() { root.checkOpaque("hover-to-context settle") }
            settleGlideThen(root._settleLabel, root._settleNext)
            root.checkClose("hover-to-context display settles on target X", host.displayX, host.targetX)
            root.checkClose("hover-to-context display settles on target W", host.displayWidth, host.targetWidth)
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
            root.checkOpaque("reopen keeps layers opaque")
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
        interval: Lazer.MotionTokens.medium + 150
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
            // Pre-exchange: same-frame state keeps A mounted and starts the glide.
            root.check("glide pre-exchange keeps current context-reopen intent",
                host.currentIntent.widgetId, "context-reopen")
            root.check("glide pre-exchange records pending context", host.pendingIntent.kind, "context")
            root.check("glide pre-exchange exposes latest root intent", host.intent.widgetId, "clock")
            root.check("glide pre-exchange resets shared progress", host.transitionProgress, 0)
            root.checkOpaque("glide pre-exchange keeps layers opaque")
            root.check("glide pre-exchange keeps interaction live", host.contentInteractive, true)
            glideMidWait.restart()
        }
    }

    // Mid-glide sample: content stays opaque, display is travelling.
    Timer {
        id: glideMidWait
        interval: 60
        onTriggered: {
            root.checkOpaque("glide mid-point keeps layers opaque")
            root.check("glide mid-point keeps host open", host.open, true)
            // Post the rapid C while the A->B glide is still travelling or
            // just exchanged: only C may commit.
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
            root.check("rapid A->B->C keeps latest pending", host.pendingIntent.widgetId,
                "clock-latest")
            root.check("rapid A->B->C exposes latest root intent", host.intent.widgetId,
                "clock-latest")
            root.checkOpaque("rapid replacement keeps layers opaque")
            glideSettleWait.restart()
        }
    }

    Timer {
        id: glideSettleWait
        interval: Lazer.MotionTokens.medium + 200
        onTriggered: {
            root.check("glide settle commits only C (never stale B)",
                host.currentIntent.widgetId, "clock-latest")
            root.check("pending intent clears after exchange", host.pendingIntent, null)
            root.check("glide settles at progress 1", host.transitionProgress, 1)
            root.checkOpaque("glide settle keeps layers opaque")
            root.checkClose("glide settle display X meets target", host.displayX, host.targetX)
            root.checkClose("glide settle display width meets target", host.displayWidth, host.targetWidth)
            root.checkClose("glide settle display height meets target", host.displayHeight, host.targetHeight)
            root._contextCallbackArgs = []
            host.contextActions.invoke("moveRight")
            root.check("hover-to-context callback receives latest instance key",
                root._contextCallbackArgs[0], "clock-latest:0")
            root.check("hover-to-context callback receives latest widget id",
                root._contextCallbackArgs[1], "clock-latest")
            root.check("hover-to-context callback receives latest section",
                root._contextCallbackArgs[2], "left")
            // Latest context callback stays bound while the popup is reused.
            root._contextCallbackArgs = []
            host.contextActions.invoke("moveRight")
            root.check("latest context callback receives instance key",
                root._contextCallbackArgs[0], "clock-latest:0")
            root.check("latest context callback receives widget id",
                root._contextCallbackArgs[1], "clock-latest")
            root.check("latest context callback receives section",
                root._contextCallbackArgs[2], "left")
            host.contextActions.invoke("close")
            // Close is async (closeTimer = MotionTokens.fast): the exit keeps
            // A rendered through the delay, then clears. Wait it out instead
            // of asserting synchronously.
            contextCloseWait.restart()
        }
    }

    Timer {
        id: contextCloseWait
        interval: Lazer.MotionTokens.fast + 60
        onTriggered: {
            root.check("context close dismisses reused host", host.open, false)
            // The exit reveal retains old content until cleanup fires.
            root.check("context close retains current intent through exit",
                host.currentIntent.widgetId, "clock-latest")
            root.check("context close retains root intent through exit",
                host.intent.widgetId, "clock-latest")
            root.check("context close clears pending immediately", host.pendingIntent, null)
            root.check("context close keeps surface through exit", host.surfaceActive, true)
            root._settleLabel = "context close settles progress"
            root._settleNext = null
            settleGlideThen(root._settleLabel, null)
            root.checkOpaque("context close keeps layers opaque")
            root.check("context close stops close timer", host.closeTimerRunning, false)
            root.check("context close starts exit cleanup", host.debugSnapshot().host.clearTimer, true)
            contextCleanupWait.restart()
        }
    }

    Timer {
        id: contextCleanupWait
        interval: host.popupItem.revealDuration + 120
        onTriggered: {
            root.check("context cleanup clears current intent", host.currentIntent, null)
            root.check("context cleanup clears root intent", host.intent, null)
            root.check("context cleanup clears surface", host.surfaceActive, false)
            root.check("context cleanup stops clear timer", host.debugSnapshot().host.clearTimer, false)

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
            root.check("dismiss test starts replacement glide", host.pendingIntent.widgetId, "dismissed")
            root.check("dismiss test keeps displayed source", host.currentIntent.widgetId, "dismiss-source")
            root.checkOpaque("dismiss pre-exchange keeps layers opaque")
            dismissDuringGlideWait.restart()
        }
    }

    Timer {
        id: dismissDuringGlideWait
        interval: 60
        onTriggered: {
            // The 45% exchange can commit before this fires; ensure a glide
            // is actually in flight so dismiss lands mid-glide deterministically.
            if (!host.pendingIntent) {
                host.updateIntent({
                    widgetId: "dismissed-2", instanceKey: "dismissed-2:0", kind: "hover",
                    actionKind: "volume", anchorX: 480, screenWidth: 1000,
                    screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
                })
            }
            root.check("dismiss test has pending intent", host.pendingIntent !== null, true)
            root.checkOpaque("dismiss mid-glide keeps layers opaque")
            host.dismissImmediately()
            root.check("dismiss during glide clears pending", host.pendingIntent, null)
            root.check("dismiss during glide settles progress", host.transitionProgress, 1)
            root.checkOpaque("dismiss during glide keeps layers opaque")

            host.showIntent({
                widgetId: "after-dismiss", instanceKey: "after-dismiss:0", kind: "context",
                anchorX: 540, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top"
            })
            root.check("new intent applies after dismiss", host.currentIntent.widgetId, "after-dismiss")
            dismissStaleGlideWait.restart()
        }
    }

    Timer {
        id: dismissStaleGlideWait
        interval: Lazer.MotionTokens.medium + 150
        onTriggered: {
            root.check("dismissed glide cannot overwrite new current intent",
                host.currentIntent.widgetId, "after-dismiss")
            root.check("dismissed glide cannot overwrite new intent",
                host.intent.widgetId, "after-dismiss")
            root.check("dismissed glide leaves pending clear", host.pendingIntent, null)
            root.checkOpaque("dismissed glide leaves layers opaque")

            // A context menu holds the popup until dismissed, and this is a
            // hover intent: release the context one the way its close button
            // does, or the replacement is refused.
            host.dismissImmediately()
            Lazer.MotionTokens.reducedMotionOverride = true
            host.updateIntent({
                widgetId: "volume", instanceKey: "volume:reduced", kind: "hover",
                actionKind: "volume", anchorX: 300, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            root.check("reduced motion applies replacement immediately",
                host.currentIntent.widgetId, "volume")
            root.check("reduced motion clears pending intent", host.pendingIntent, null)
            root.check("reduced motion settles progress", host.transitionProgress, 1)
            root.check("reduced motion settles display X", host.displayX, host.targetX)
            root.check("reduced motion settles display width", host.displayWidth, host.targetWidth)
            root.check("reduced motion settles display height", host.displayHeight, host.targetHeight)
            root.checkOpaque("reduced motion keeps layers opaque")
            reducedMotionSettleWait.restart()
        }
    }

    Timer {
        id: reducedMotionSettleWait
        // Reveal can still be flying from the fresh after-dismiss open when
        // the reduced commit lands; give it full margin (flake guard).
        interval: host.popupItem.revealDuration + 400
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
            root.check("natural close settles progress", host.transitionProgress, 1)
            root.checkOpaque("natural close keeps layers opaque")
            root.check("natural close timer is stopped", host.closeTimerRunning, false)
            root.check("natural close leaves popup owner available", host.popupItem !== null, true)
            // Tray delegates share one widget identity: a different icon id
            // must glide and slide like a cross-widget switch, while the same
            // icon refreshing its label stays live in place.
            host.showIntent({
                widgetId: "tray", instanceKey: "tray:0", kind: "hover",
                title: "App A", actionKind: "tray", delegateKey: "sni-a",
                anchorX: 600, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.updateIntent({
                widgetId: "tray", instanceKey: "tray:0", kind: "hover",
                title: "App B", actionKind: "tray", delegateKey: "sni-b",
                anchorX: 660, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            root.check("tray icon switch starts replacement", host.pendingIntent.delegateKey, "sni-b")
            root.check("tray icon switch keeps current icon", host.currentIntent.delegateKey, "sni-a")
            host.transitionProgress = 0.5
            root.check("tray switch slides new icon in from right", host.contentSlideSign, 1)
            host.contentSlideProgress = 0.5
            var trayInIdentity = root.findByName(host.popupItem, "popupIdentity")
            var trayOutIdentity = root.findByName(host.popupItem, "popupIdentityOutgoing")
            root.check("tray switch moves identity in from right", trayInIdentity.x > 0, true)
            root.check("tray switch moves identity out to left", trayOutIdentity.x < 0, true)
            // Regression: the tray content canvas reserves a second-level band so
            // the overflowing catcher has ancestors to hit-test against, and it is
            // wider than the 260 panel it paints. A body entering from outside the
            // panel has to be bounded by the slot, because `Item.clip` clips a
            // child to the CLIPPING item's own rect - clipping the body itself
            // only trims the body's own children and leaves it painting at x=260
            // against a 260 panel, which reads as a menu smearing across the
            // desktop while swapping icons.
            var traySlot = root.findByName(host.popupItem, "popupContentSlot")
            var trayInBody = root.findByName(host.popupItem, "popupActions")
            var trayOutBody = root.findByName(host.popupItem, "popupActionsOutgoing")
            root.check("tray switch canvas is wider than the painted panel",
                host.popupContentWidth > host.popupSlotWidth, true)
            // At the start of the slide the incoming body rests one panel width
            // out, entirely outside what the panel owns. That is the frame that
            // smears across the desktop when nothing bounds it, so park the
            // clock there and confirm the slot is already the panel width.
            host.contentSlideProgress = 0
            root.check("tray switch starts the body one panel outside",
                trayInBody.x, host._contentSlideDistance)
            root.check("tray switch bounds the slot to the painted panel",
                traySlot.width, host.popupSlotWidth)
            root.check("tray switch clips the slot while displaced",
                traySlot.clip, true)
            root.check("tray switch tracks one painted panel width",
                host._contentSlideDistance, host.popupSlotWidth)
            // Reaching 1 is not the end of the exchange: the outgoing layer is
            // still mounted, so the bound must still hold.
            host.contentSlideProgress = 1
            root.check("finished slide keeps the bound while outgoing is mounted",
                traySlot.width, host.paintedPanelWidth)
            root.check("finished slide rests the incoming body at the origin",
                trayInBody.x, 0)
            host.settleContentSlide()
            root.check("torn-down exchange restores the input canvas",
                traySlot.width, host.popupContentWidth)
            // Moving back left mirrors the track.
            host.updateIntent({
                widgetId: "tray", instanceKey: "tray:0", kind: "hover",
                title: "App A", actionKind: "tray", delegateKey: "sni-a",
                anchorX: 600, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.transitionProgress = 0.5
            root.check("tray switch back flips slide sign", host.contentSlideSign, -1)
            host.contentSlideProgress = 1
            host.settleContentSlide()
            // Same icon refreshing its label stays live without a transition.
            host.updateIntent({
                widgetId: "tray", instanceKey: "tray:0", kind: "hover",
                title: "App A (2)", actionKind: "tray", delegateKey: "sni-a",
                anchorX: 600, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            root.check("tray label refresh clears pending", host.pendingIntent, null)
            root.check("tray label refresh updates live", host.currentIntent.title, "App A (2)")
            root.check("tray label refresh keeps no outgoing layer", host._transitionOutgoingIntent, null)

            // Regression: a second hover landing mid-slide resets
            // _exchangeCommitted while both bodies are still offset. If the slot
            // widens back to the input canvas on that flag alone, the
            // still-displaced body paints outside the panel for the rest of the
            // cascade - the menu flashing beside the popup.
            host.updateIntent({
                widgetId: "tray", instanceKey: "tray:0", kind: "hover",
                title: "App C", actionKind: "tray", delegateKey: "sni-c",
                anchorX: 720, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.transitionProgress = 0.5
            host.contentSlideProgress = 0.5
            var cascadeSlot = root.findByName(host.popupItem, "popupContentSlot")
            var cascadeBody = root.findByName(host.popupItem, "popupActions")
            root.check("mid-slide cascade keeps a body displaced",
                Math.abs(cascadeBody.x) > 0.5, true)
            root.check("mid-slide cascade keeps the slot bounded to the panel",
                cascadeSlot.width, host.popupSlotWidth)
            host.contentSlideProgress = 1
            host.settleContentSlide()
            // Regression: the exact frame the slide reaches 1 but the outgoing
            // layer has not been torn down yet. Releasing the bound on progress
            // alone let the still-mounted outgoing body paint at full offset for
            // one frame - a tray menu whose rows have not loaded yet, so empty
            // cards floating to the right of the panel with nothing behind them.
            host.updateIntent({
                widgetId: "tray", instanceKey: "tray:2", kind: "hover",
                title: "App E", actionKind: "tray", delegateKey: "sni-e",
                anchorX: 500, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.transitionProgress = 0.5
            host.contentSlideProgress = 1
            var gapSlot = root.findByName(host.popupItem, "popupContentSlot")
            var gapOut = root.findByName(host.popupItem, "popupActionsOutgoing")
            root.check("outgoing layer is still mounted at progress 1",
                gapOut.visible, true)
            root.check("tear-down gap keeps the slot bounded to the panel",
                gapSlot.width, host.paintedPanelWidth)
            // The outgoing body is at full offset, entirely outside the narrowed
            // slot, so the slot's clip is what keeps it off the desktop.
            root.check("tear-down gap keeps the slot clipped",
                gapSlot.clip, true)
            root.check("tear-down gap leaves the outgoing body fully clipped away",
                gapOut.x >= gapSlot.width - 0.5, true)
            host.settleContentSlide()
            root.check("settling releases the bound",
                gapSlot.width, host.popupContentWidth)

            // Regression: a body that has not been measured yet must not
            // collapse the slot to 1px while still painting at full height.
            // A context menu's column only exists once it is on screen, and a
            // tray menu awaits an async DBus fetch, so the window where the
            // slot reads 0 is exactly the window where the menu renders outside
            // its own clip - the whole menu appearing under the panel it was
            // replacing.
            var measureSlot = root.findByName(host.popupItem, "popupContentSlot")
            var measuredNow = host.measuredContentHeight(host.currentIntent)
            root.check("a measured body reports a real height", measuredNow > 1, true)
            root.check("measured height reaches the slot", measureSlot.height > 1, true)
            host._lastMeasuredHeight = measuredNow
            // Simulate the unmeasured window: the body measures 0 but stays
            // mounted, which is what a pending tray fetch looks like.
            var ctxBody = root.findByName(host.popupItem, "contextPopupActions")
            // The content fix makes height independent of `visible`, so a hidden
            // context body still measures its real height - that independence is
            // what broke the measurement/drawing cycle. Assert it directly.
            var heightWhenHidden = ctxBody.implicitHeight
            root.check("context body height does not depend on visible",
                heightWhenHidden > 1, true)
            ctxBody.visible = false
            root.check("hidden context body keeps its measured height",
                ctxBody.implicitHeight > 1, true)
            ctxBody.visible = true
            // And with no measurement available at all, the slot holds the last
            // real height instead of collapsing to 1px.
            var heldBefore = host.popupHeightForIntent(host.currentIntent)
            host._lastMeasuredHeight = 260
            root.check("empty measurement holds the last real height",
                host.popupHeightForIntent(null), 260)
            root.check("a real measurement wins over the held height",
                heldBefore, measuredNow)

            // Regression: a hop between bodies of DIFFERENT widths. The slot was
            // bounded to the wider of the two, so on media(420) -> tray(260) the
            // incoming tray face started one 420px track out and painted 160px
            // to the right of its own 260 panel - the occasional flash beside the
            // menu, which only showed on mixed-width hops.
            host.showIntent({
                widgetId: "wide", instanceKey: "wide:0", kind: "hover",
                title: "Media", actionKind: "media", anchorX: 700,
                screenWidth: 1000, screenHeight: 800, effectiveBarHeight: 48,
                barPosition: "top", payload: {}
            })
            host.popupItem.revealProgress = 1
            host.transitionProgress = 1
            host.updateIntent({
                widgetId: "tray", instanceKey: "tray:1", kind: "hover",
                title: "App D", actionKind: "tray", delegateKey: "sni-d",
                anchorX: 700, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.transitionProgress = 0.5
            host.contentSlideProgress = 0
            var mixedSlot = root.findByName(host.popupItem, "popupContentSlot")
            var mixedBody = root.findByName(host.popupItem, "popupActions")
            root.check("mixed hop slot matches the incoming panel, not the wider body",
                mixedSlot.width, host.trayFaceWidth)
            // The body travels the full 420 track, so at progress 0 it is
            // outside the 260 panel and the slot must clip it away entirely.
            root.check("mixed hop slot is the incoming panel width",
                mixedSlot.width, host.trayFaceWidth)
            root.check("mixed hop starts the incoming face fully outside",
                mixedBody.x >= mixedSlot.width - 0.5, true)
            host.contentSlideProgress = 1
            host.settleContentSlide()
            root.check("settled mixed hop restores the tray input canvas",
                mixedSlot.width, host.popupContentWidth)
            // Hand the host back closed, as the tray block above does, so the
            // sections after this one start from a known state.
            host.dismissImmediately()

            // The flip compensation translates the whole content layer with a
            // Binding, so it can carry the slot past the panel without any clip
            // seeing it. Drive the flip and check the painted surface stays
            // inside the popup.
            host.showIntent({
                widgetId: "tray", instanceKey: "tray:8", kind: "hover",
                title: "Edge A", actionKind: "tray", delegateKey: "sni-e1",
                anchorX: 975, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.popupItem.revealProgress = 1
            host.transitionProgress = 1
            host.updateIntent({
                widgetId: "tray", instanceKey: "tray:9", kind: "hover",
                title: "Edge B", actionKind: "tray", delegateKey: "sni-e2",
                anchorX: 940, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.transitionProgress = 0.5
            host.contentSlideProgress = 0.5
            var flipBody = root.findByName(host.popupItem, "popupActions")
            if (flipBody && flipBody.trayMenuContent) {
                flipBody.trayMenuContent.submenuProgress = 1
                host.submenuFlipped = true
                host.flipBaseX = host.displayX
                host.displayX = host.displayX - 40
                host.transitionProgress = 0.5
                var shiftSlot = root.findByName(host.popupItem, "popupContentSlot")
                var surface = root.findByName(host.popupItem, "popupContentSurface")
                // The shift tracks the container's own leftward expansion, so
                // read it rather than assume the sample's arithmetic.
                root.check("flipped content layer tracks the flip delta",
                    host.contentShiftX,
                    Math.round((host.flipBaseX - host.displayX) * 10) / 10)
                root.check("flipped slot stays bounded to the incoming panel",
                    shiftSlot.width, host.paintedPanelWidth)
                // The Binding moves the whole layer, so the panel surface and
                // the slot travel together and the slot may never sit past the
                // surface it is clipped against.
                var flipSurface = root.findByName(host.popupItem, "popupContentSurface")
                root.check("flipped slot never sits past the panel surface",
                    shiftSlot.x + shiftSlot.width <= flipSurface.width + 0.5, true)
                flipBody.trayMenuContent.submenuProgress = 0
                host.submenuFlipped = false
            }
            host.contentSlideProgress = 1
            host.settleContentSlide()
            host.dismissImmediately()

            // Restore the closed state the close-race block below expects.
            host.dismissImmediately()
            root.check("tray phase dismiss closes host", host.open, false)
            root.check("tray phase dismiss clears current", host.currentIntent, null)
            // Start a replacement, then naturally close while its glide is
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
            root.check("close race starts replacement", host.pendingIntent.widgetId, "race-b")
            root.check("close race keeps displayed A immediately", host.currentIntent.widgetId, "race-a")
            host.widgetHovered = false
            host.popupHovered = false
            host.requestClose()
            root.check("close race invalidates replacement immediately", host.pendingIntent, null)
            root.check("close race keeps displayed A immediately", host.currentIntent.widgetId, "race-a")
            closeDuringReplacementWait.restart()
        }
    }

    Timer {
        id: closeDuringReplacementWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("close race closes before exchange applies", host.open, false)
            root.check("close race keeps displayed A after glide settles",
                host.currentIntent.widgetId, "race-a")
            root.check("close race retains root intent during exit", host.intent.widgetId, "race-b")
            root.check("close race clears pending replacement", host.pendingIntent, null)
            root.checkOpaque("close race keeps layers opaque")
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
            // Revive phase: open a popup and settle its reveal, then simulate
            // a freshly-fired close (exit starts from full reveal with zero
            // frames elapsed) before interrupting it with a new intent.
            host.showIntent({
                widgetId: "revive-a", instanceKey: "revive-a:0", kind: "hover",
                title: "Revive A", actionKind: "volume",
                anchorX: 300, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            reviveOpenSettleWait.restart()
        }
    }

    Timer {
        id: reviveOpenSettleWait
        interval: host.popupItem.revealDuration + 400
        onTriggered: {
            root.check("revive setup opens host", host.open, true)
            root.check("revive setup settles reveal", host.popupItem.revealProgress > 0.99, true)
            host.open = false
            root.check("revive setup retains surface through exit", host.surfaceActive, true)
            // A new widget arriving mid-exit must revive the live popup:
            // glide + slide continue instead of snapping open.
            host.updateIntent({
                widgetId: "network", instanceKey: "network:0", kind: "hover",
                title: "Network", actionKind: "network",
                anchorX: 700, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            root.check("revive reopens host", host.open, true)
            root.check("revive starts replacement", host.pendingIntent.widgetId, "network")
            root.check("revive keeps displayed A", host.currentIntent.widgetId, "revive-a")
            root.check("revive does not snap reveal", host.popupItem.revealProgress, 1)
            host.transitionProgress = 0.5
            root.check("revive commits B at exchange", host.currentIntent.widgetId, "network")
            host.contentSlideProgress = 0.5
            var reviveIn = root.findByName(host.popupItem, "popupIdentity")
            var reviveOut = root.findByName(host.popupItem, "popupIdentityOutgoing")
            root.check("revive slides new content in from right", reviveIn.x > 0, true)
            root.check("revive slides old content out to left", reviveOut.x < 0, true)
            host.contentSlideProgress = 1
            host.settleContentSlide()
            reviveGlideWait.restart()
        }
    }

    Timer {
        id: reviveGlideWait
        interval: Lazer.MotionTokens.medium + Lazer.MotionTokens.slow + 300
        onTriggered: {
            root.check("revive settles on B", host.currentIntent.widgetId, "network")
            root.check("revive clears pending", host.pendingIntent, null)
            root.check("revive restores full reveal", host.popupItem.revealProgress > 0.99, true)
            root.checkClose("revive display X meets target", host.displayX, host.targetX)
            root.check("revive clears outgoing layer", host._transitionOutgoingIntent, null)
            // Same widget re-hovered mid-exit revives live without a swap.
            host.widgetHovered = false
            host.popupHovered = false
            host.requestClose()
            reviveSameCloseWait.restart()
        }
    }

    Timer {
        id: reviveSameCloseWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            host.updateIntent({
                widgetId: "network", instanceKey: "network:0", kind: "hover",
                title: "Network (2)", actionKind: "network",
                anchorX: 700, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            root.check("same-widget revive reopens host", host.open, true)
            root.check("same-widget revive clears pending", host.pendingIntent, null)
            root.check("same-widget revive updates live", host.currentIntent.title, "Network (2)")
            root.check("same-widget revive keeps no outgoing layer", host._transitionOutgoingIntent, null)
            reviveSameSettleWait.restart()
        }
    }

    Timer {
        id: reviveSameSettleWait
        interval: host.popupItem.revealDuration + 400
        onTriggered: {
            root.check("same-widget revive stays open", host.open, true)
            root.check("same-widget revive restores reveal", host.popupItem.revealProgress > 0.99, true)
            // Mid-transition close: exchange commits, then the pointer leaves
            // before the slide finishes. The exit must not snap content to
            // its end state.
            host.updateIntent({
                widgetId: "volume", instanceKey: "volume:0", kind: "hover",
                title: "Volume", actionKind: "volume",
                anchorX: 200, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.transitionProgress = 0.5
            host.widgetHovered = false
            host.popupHovered = false
            host.requestClose()
            root.check("mid-transition close keeps exchange committed", host._exchangeCommitted, true)
            root.check("mid-transition close retains outgoing layer",
                host._transitionOutgoingIntent.widgetId, "network")
            host.contentSlideProgress = 0.5
            var midIn = root.findByName(host.popupItem, "popupIdentity")
            var midOut = root.findByName(host.popupItem, "popupIdentityOutgoing")
            root.check("mid-transition close keeps incoming sliding", midIn.x < 0, true)
            root.check("mid-transition close keeps outgoing sliding", midOut.x > 0, true)
            midCloseFiredWait.restart()
        }
    }

    Timer {
        id: midCloseFiredWait
        interval: Lazer.MotionTokens.fast + 40
        onTriggered: {
            root.check("mid-transition close fires", host.open, false)
            root.check("mid-transition close retains new content", host.currentIntent.widgetId, "volume")
            root.check("mid-transition exit keeps outgoing layer",
                host._transitionOutgoingIntent !== null, true)
            root.check("mid-transition exit keeps slide running", host.contentSlideProgress < 1, true)
            midCloseCleanupWait.restart()
        }
    }

    Timer {
        id: midCloseCleanupWait
        interval: host.popupItem.revealDuration + Lazer.MotionTokens.slow + 400
        onTriggered: {
            root.check("mid-transition cleanup clears current", host.currentIntent, null)
            root.check("mid-transition cleanup clears surface", host.surfaceActive, false)
            // Regression: height arriving mid-reveal must rebase live so the
            // shell has already settled once fully expanded (no second motion
            // after expansion). Stale display must catch up synchronously.
            host.showIntent({
                widgetId: "volume", instanceKey: "volume:0", kind: "hover",
                title: "Volume", actionKind: "volume",
                anchorX: 200, screenWidth: 1000, screenHeight: 800,
                effectiveBarHeight: 48, barPosition: "top", payload: {}
            })
            host.popupItem.revealProgress = 0.5
            host.displayHeight = 7
            host.updateTargetGeometry(host.currentIntent)
            root.check("mid-reveal height rebases live instead of lagging expansion",
                host.displayHeight, host.targetHeight)
            host.dismissImmediately()
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
            root.check("popup viewport retains screen clipping", host.popupViewportItem.clip, true)
            root.check("ordinary hover content stays inside its slot",
                root.findByName(host.popupItem, "popupContentSlot").clip, true)
            // Slide contract: layers travel the full container distance behind
            // the bar clip edge instead of relying on the opacity channel.
            root.check("identity layer slides from behind bar", host.popupItem.sidebarOffset !== 0, true)
            root.check("content delay is zero (no opacity staging)",
                host.popupItem.contentDelay, 0)
            root.check("content layer travels farther than identity",
                Math.abs(host.popupItem.contentOffset) > Math.abs(host.popupItem.sidebarOffset), true)
            root.check("reveal is geometric (opacity channel off)", host.popupItem.animateLayerOpacity, false)
            root.check("reveal state is active while open",
                host.surfaceActive && host.popupItem.visible, true)
            root.check("reveal viewport covers complete target",
                host.popupViewportItem.height >= host.targetHeight
                || host.popupItem.height >= host.targetHeight, true)
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
            var identityHeight = Math.max(Number(host.popupItem.sidebarLayer.implicitHeight),
                Number(host.popupItem.sidebarLayer.height), 48)
            var expectedHoverHeight = identityHeight + hoverSlotHeight + 1
            root.check("hover height selects hover implicit height", host.targetHeight, expectedHoverHeight)
            var beforeSlideSlotHeight = Number(root.findByName(host.popupItem, "popupContentSlot").height)
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
            root.check("replacement starts shared glide", host.transitionProgress, 0)
            root.checkOpaque("replacement keeps layers opaque")
            root.check("replacement target remains screen-clamped", host.targetX >= 8 && host.targetX <= 1000 - host.targetWidth - 8, true)
            root.check("replacement target keeps current kind height", host.targetHeight, expectedHoverHeight)

            // The exchange keeps both contents mounted: the outgoing layer
            // exits along the pointer trail while the incoming enters from
            // the travel direction, both on the dedicated slide clock.
            host.transitionProgress = 0.5
            var slideSlot = root.findByName(host.popupItem, "popupContentSlot")
            root.check("exchange retargets slot natural height", slideSlot.implicitHeight !== beforeSlideSlotHeight, true)
            root.check("exchange animates slot height instead of snapping", slideSlot.height, beforeSlideSlotHeight)
            var incomingIdentity = root.findByName(host.popupItem, "popupIdentity")
            var outgoingIdentity = root.findByName(host.popupItem, "popupIdentityOutgoing")
            var incomingActions = root.findByName(host.popupItem, "popupActions")
            var outgoingActions = root.findByName(host.popupItem, "popupActionsOutgoing")
            root.check("content exchange creates outgoing identity", outgoingIdentity !== null, true)
            root.check("content exchange keeps outgoing identity visible", outgoingIdentity.visible, true)
            // Regression: an open tray submenu must not open the slot clip
            // while both bodies slide; otherwise the incoming/outgoing layers
            // paint past the slot edge during tray-icon switches.
            var trayIncoming = incomingActions.trayMenuContent
            if (trayIncoming)
                trayIncoming.submenuProgress = 1
            root.check("exchange with submenu open keeps slot clipped",
                slideSlot.clip, true)
            // The layer-shell mask must already cover the second level when it
            // is summoned. Sizing it off the animated container width left the
            // panel painted outside the region: the pointer crossing toward it
            // produced a compositor leave and the popup closed under it, which
            // is why only the first submenu of a session was unreachable.
            var inputRegion = root.findByName(host.popupViewportItem, "popupInputRegion")
            root.check("input region item exists", inputRegion !== null, true)
            if (inputRegion) {
                root.check("input region covers the summoned submenu column",
                    inputRegion.width >= host.targetWidth, true)
                root.check("input region covers the submenu column right edge",
                    inputRegion.x + inputRegion.width
                        >= host.targetX + host.targetWidth, true)
                // The snapshot's input block is the only thing that tells a
                // dropped-by-the-compositor event apart from one the tray never
                // received. A ReferenceError in it silently kills the whole
                // timeline, which reads exactly like "nothing happened" — so
                // assert the block actually builds while a submenu is open.
                var snap = null
                var snapError = ""
                try {
                    snap = host.debugSnapshot()
                } catch (e) {
                    snapError = String(e)
                }
                root.check("debug snapshot builds with a submenu open", snapError, "")
                if (snap) {
                    root.check("snapshot carries the input block", snap.input !== undefined, true)
                    root.check("snapshot reports the active region",
                        Number(snap.input.region.width) > 0, true)
                    if (trayIncoming && trayIncoming.lastCursorX >= 0) {
                        root.check("snapshot maps the cursor into the region",
                            snap.input.cursorInRegion, true)
                    }
                    // The band collapses to zero height when the primary list has
                    // no rows and the panel has no body, so only its horizontal
                    // reach is meaningful here: that is the axis the submenu
                    // extends along, and the one that must never leave the region.
                    var colRect = snap.tray ? snap.tray.column : null
                    if (colRect && Number(colRect.height) > 0) {
                        root.check("snapshot says the submenu column is inside the region",
                            snap.input.columnInRegion, true)
                    } else {
                        root.check("input region still spans the submenu column",
                            Number(snap.input.region.x) + Number(snap.input.region.width)
                                >= Number(colRect.x) + Number(colRect.width), true)
                    }
                    // The region must not track the animating container. Every
                    // geometry change re-commits set_input_region and the
                    // compositor re-evaluates pointer focus on each commit, so a
                    // mask that glides with the container re-commits ~30 times
                    // per submenu flight. A leave is only undone by physical
                    // motion, so a parked cursor never gets the pointer back.
                    var widthsSeen = []
                    var containerBefore = host.displayWidth
                    for (var wstep = 0; wstep < 6; wstep++) {
                        host.displayWidth = containerBefore + wstep * 40
                        widthsSeen.push(root.findByName(host.popupViewportItem,
                            "popupInputRegion").width)
                    }
                    host.displayWidth = containerBefore
                    var uniqueWidths = widthsSeen.filter(function(v, idx, arr) {
                        return arr.indexOf(v) === idx
                    })
                    root.check("input region does not follow the animating container",
                        uniqueWidths.length, 1)
                    // The region must be latched to one rect per target commit.
                    // Four independent bindings produced four geometry changes
                    // per commit, and each one re-commits set_input_region and
                    // makes the compositor re-evaluate pointer focus — measured
                    // as six commits while a first open was still settling.
                    var commitsBefore = host._regionCommits
                    var targetBefore = { x: host.targetX, y: host.targetY,
                        w: host.targetWidth, h: host.targetHeight }
                    host.updateTargetGeometry(host.currentIntent, true)
                    root.check("one target commit re-commits the region at most twice",
                        host._regionCommits - commitsBefore <= 2, true)
                    root.check("the latched region tracks the committed target x",
                        host.regionRect.x, targetBefore.x)
                    // The tray must reserve its submenu column up front. Growing
                    // the region on summon re-commits set_input_region while the
                    // pointer is travelling toward the second level, and the
                    // compositor re-evaluates pointer focus on that commit —
                    // which is why only the first expand of a session failed.
                    if (trayIncoming) {
                        var trayTarget = host.targetWidth
                        host.updateTargetGeometry({
                            widgetId: "tray", instanceKey: "tray", kind: "hover",
                            actionKind: "tray", anchorX: 1251
                        })
                        root.check("a tray popup reserves its submenu column",
                            host.regionRect.width >= trayTarget, true)
                    }
                    // The first open in a session commits the target geometry
                    // before the content tree has laid out, so targetY and
                    // targetHeight are still their property defaults. The
                    // surface then maps against a region built from placeholders
                    // — a 260x50 strip at the top-left of the screen — and the
                    // pointer is lost before revealStartTimer fixes it up to
                    // 960ms later. That is the whole of "only the first
                    // expand": every later open maps with a real region.
                    // The rebase-on-first-open invariant is asserted at the end of
                    // the sequence, where mutating the shared host is safe.
                    root.check("region item exists for the input mask",
                        root.findByName(host.popupViewportItem,
                            "popupInputRegion") !== null, true)
                }
                // The close rule: a leave reported from INSIDE the region is not
                // the user leaving. Measured on the desktop as 1366.9,113.5 —
                // the pointer had crossed into the submenu column and was still
                // over the popup when the leave fired, and closing on it is what
                // made the first expand dead. A departure outside the region
                // must still close, or the popup would never go away.
                root.check("host starts with no pending inside-region departure",
                    host._departureInsideRegion, false)
                // The host maps tray-content coordinates into region space, so
                // pick a region point that is unambiguously covered and invert it
                // into tray coordinates. Deriving it beats hardcoding: the tray's
                // own origin is mid-slide during the exchange and lands outside.
                var regionNow = host.debugSnapshot().input.region
                var insideRegion = trayIncoming.mapFromItem(host.popupViewportItem,
                    Number(regionNow.x) + 10, Number(regionNow.y) + 10)
                host.onTrayPointerDeparted(insideRegion.x, insideRegion.y,
                    "primary-catcher")
                root.check("a departure inside the region is marked as such",
                    host._departureInsideRegion, true)
                host.onTrayPointerDeparted(-5000, 5, "primary-catcher")
                root.check("a departure outside the region is not inside",
                    host._departureInsideRegion, false)
                host.onTrayPointerDeparted(NaN, NaN, "primary-catcher")
                root.check("a departure with no usable pointer is not inside",
                    host._departureInsideRegion, false)
            }
            if (trayIncoming)
                trayIncoming.submenuProgress = 0
            root.check("exchange starts incoming transparent", incomingActions.opacity, 0)
            root.check("exchange starts outgoing opaque", outgoingActions.opacity, 1)
            host.contentSlideProgress = 0.5
            root.check("content exchange moves identity in from right", incomingIdentity.x > 0, true)
            root.check("content exchange moves identity out to left", outgoingIdentity.x < 0, true)
            root.check("content exchange moves body in from right", incomingActions.x > 0, true)
            root.check("content exchange moves body out to left", outgoingActions.x < 0, true)
            root.checkClose("content exchange fades incoming body in", incomingActions.opacity, 0.5, 0.05)
            root.checkClose("content exchange fades outgoing body out", outgoingActions.opacity, 0.5, 0.05)
            root.checkClose("content exchange fades identity in", incomingIdentity.foregroundOpacity, 0.5, 0.05)
            root.checkClose("content exchange fades identity out", outgoingIdentity.foregroundOpacity, 0.5, 0.05)
            root.check("content exchange keeps identity rail opaque", incomingIdentity.opacity, 1)
            host.contentSlideProgress = 1
            host.settleContentSlide()
            root.check("settled exchange restores incoming opacity", incomingActions.opacity, 1)
            root.check("settled exchange restores identity foreground", incomingIdentity.foregroundOpacity, 1)
            root.check("settled exchange clears outgoing identity", outgoingIdentity.visible, false)
            root.check("settled exchange clears outgoing body", outgoingActions.visible, false)

            // The exchange above committed the context intent, and a context
            // menu holds the popup until it is dismissed - so release it the way
            // its own close button does before the hover sequence continues.
            root.check("context intent is what the exchange committed",
                host.currentIntent.widgetId, "notifications")
            host.dismissImmediately()
            host.widgetHovered = true
            // Reopen, then replace: the assertion below needs a live popup with a
            // pending second intent, which a single fresh intent cannot produce.
            host.updateIntent({
                widgetId: "battery", instanceKey: "battery:0", kind: "hover",
                actionKind: "battery", anchorX: 600, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            root.check("hover reopens after the context menu is dismissed",
                host.currentIntent.widgetId, "battery")
            host.updateIntent({
                widgetId: "brightness", instanceKey: "brightness:0", kind: "hover",
                actionKind: "brightness", anchorX: 520, screenWidth: 1000,
                screenHeight: 800, effectiveBarHeight: 48, barPosition: "top"
            })
            root.check("rapid replacement keeps latest pending target",
                host.pendingIntent.widgetId, "brightness")

            // Leftward travel mirrors the track: the incoming layer enters
            // from the left edge and the outgoing exits right.
            // NOTE: the first-open rebase assertion below mutates the shared
            // host (it opens a popup), so it runs last in this sequence.
            host.transitionProgress = 0.5
            root.check("leftward exchange flips slide sign", host.contentSlideSign, -1)
            host.contentSlideProgress = 0.5
            root.check("leftward exchange enters identity from left", incomingIdentity.x < 0, true)
            root.check("leftward exchange exits identity right", outgoingIdentity.x > 0, true)
            host.contentSlideProgress = 1
            host.settleContentSlide()
            root.check("leftward settle clears outgoing identity", outgoingIdentity.visible, false)

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
            root.check("dismissImmediately settles progress", host.transitionProgress, 1)
            root.checkOpaque("dismissImmediately keeps layers opaque")
            root.check("dismissImmediately stops clear timer", host.debugSnapshot().host.clearTimer, false)

            host.showIntent(contextIntent)
            Qt.callLater(function () {
                root.check("context open initializes current intent", host.currentIntent.kind, "context")
                // Live slot height (content can grow with new rows/fonts; never hardcode).
                var ctxSlotHeight = host.popupHeightForIntent(host.currentIntent)
                root.check("context slot height positive", ctxSlotHeight > 0, true)
                root.check("context target follows context height", host.targetHeight,
                    Math.max(Number(host.popupItem.sidebarLayer.implicitHeight),
                        Number(host.popupItem.sidebarLayer.height), 48) + ctxSlotHeight + 1)
                root.startContextHoldChecks()
                root.startBottomBarChecks()
                // Last, because it mutates the shared host: a first open commits
                // its target geometry before the content has laid out, so
                // targetY/targetHeight are placeholders and the surface maps
                // against a region built from them — a 260x50 strip at the
                // top-left, nowhere near the popup. The pointer is lost long
                // before revealStartTimer corrects it. That is the whole of
                // "only the first expand"; later opens map with a real region.
                host._hasRevealed = false
                host.open = false
                host.surfaceActive = false
                host.updateIntent({
                    widgetId: "tray", instanceKey: "tray", kind: "hover",
                    actionKind: "tray", anchorX: 1251
                })
                root.check("a first open homes the container onto its target",
                    Math.abs(host.displayX - host.targetX) < 0.5, true)
                root.check("a first open has a usable input region height",
                    Number(root.findByName(host.popupViewportItem,
                        "popupInputRegion").height) > 48, true)
            })
        })
    }

    // B: a context menu holds the popup until it is explicitly dismissed. A
    // hover intent arriving underneath must not take it over - that swap is what
    // left the right-click menu mounted beside the tray menu, and reviving it
    // mid-close is what made it flash during a fast sweep between two icons.
    function startContextHoldChecks() {
        var ctx = {
            widgetId: "hold-ctx", instanceKey: "hold-ctx:0", kind: "context",
            actionKind: "", anchorX: 300, screenWidth: 1000, screenHeight: 800,
            effectiveBarHeight: 48, barPosition: "top", section: "center",
            hasSettings: false, payload: {}
        }
        host.dismissImmediately()
        host.widgetHovered = true
        host.showIntent(ctx)
        root.check("context menu opens as current", host.currentIntent.widgetId, "hold-ctx")

        host.updateIntent({
            widgetId: "tray", instanceKey: "tray:hold", kind: "hover",
            actionKind: "tray", delegateKey: "sni-hold", anchorX: 320,
            screenWidth: 1000, screenHeight: 800, effectiveBarHeight: 48,
            barPosition: "top", payload: {}
        })
        root.check("hover cannot take over a context menu", host.currentIntent.widgetId, "hold-ctx")
        root.check("context menu refuses the hover replacement",
            host.pendingIntent, null)
        root.check("context menu stays open against a hover", host.open, true)

        // Another context menu may still replace it: a right-click elsewhere.
        var ctx2 = {
            widgetId: "hold-ctx2", instanceKey: "hold-ctx2:0", kind: "context",
            actionKind: "", anchorX: 360, screenWidth: 1000, screenHeight: 800,
            effectiveBarHeight: 48, barPosition: "top", section: "center",
            hasSettings: false, payload: {}
        }
        host.updateIntent(ctx2)
        root.check("a second context menu is accepted", host.intent.widgetId, "hold-ctx2")
        host.transitionProgress = 0.5
        host.commitExchange(host.transitionSerial)
        root.check("a second context menu replaces the first",
            host.currentIntent.widgetId, "hold-ctx2")

        // Explicit dismissal releases the hold, and hover works again.
        host.dismissImmediately()
        host.widgetHovered = true
        host.updateIntent({
            widgetId: "tray", instanceKey: "tray:after-hold", kind: "hover",
            actionKind: "tray", delegateKey: "sni-after", anchorX: 320,
            screenWidth: 1000, screenHeight: 800, effectiveBarHeight: 48,
            barPosition: "top", payload: {}
        })
        // The tray body owns widgetId, so identify the reopen by kind rather
        // than by the id this harness happens to pass in.
        root.check("hover reopens once the context menu is dismissed",
            String(host.currentIntent.kind || ""), "hover")
        root.check("reopened hover is the tray intent, not the context one",
            String(host.currentIntent.actionKind || ""), "tray")
        root.check("hold released, no pending intent left", host.pendingIntent, null)
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
        // A context menu holds the popup until it is dismissed, and this switch
        // is a tray intent, so release the context one first - its own close
        // button does exactly this.
        host.dismissImmediately()
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
            root.check("open hover-to-context starts shared glide", host.transitionProgress, 0)
            root.checkOpaque("open hover-to-context keeps layers opaque")
            openHoverContextReplacementWait.restart()
        })
    }
}
