import QtQuick
import Quickshell
import "modules/bar" as Bar
import "modules/bar/widgets" as Widgets
import "modules/lazerbar" as Lazer
import "modules/bar/BarHoverLogic.js" as BarHoverLogic

// qs behavior harness for Task 5 integration.
// Verifies top/bottom direction, edge anchors, hover bridge and callbacks.
// Run with: qs -p tst_bar_two_layer_popup.qml
Item {
    id: root
    width: 1
    height: 1

    property int _failures: 0
    property int _checks: 0
    property bool _mediaReactiveVerified: false

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        root._failures += 1
        console.log("FAIL:", label, "expected", JSON.stringify(expected), "got", JSON.stringify(actual))
    }

    function checkTrue(label, value) {
        root._checks += 1
        if (value) {
            console.log("PASS:", label)
            return
        }
        root._failures += 1
        console.log("FAIL:", label, "expected true got", JSON.stringify(value))
    }

    function finish() {
        console.log("Totals:", (root._checks - root._failures), "passed,", root._failures, "failed")
        var forcedFailure = Quickshell.env("AFLOAT_TASK5_FORCE_FAILURE") === "1"
        if (root._failures === 0 && !forcedFailure) {
            Qt.quit()
            return
        }
        // The local Quickshell host exposes Qt.quit() without an exit code.
        // Terminating this process makes assertion failures machine-detectable.
        Quickshell.execDetached(["sh", "-c", "kill -TERM " + Quickshell.processId])
    }

    function findByName(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var r = findByName(kids[i], name)
                if (r) return r
            }
        }
        var dataList = item.data
        if (dataList && dataList !== kids) {
            for (var j = 0; j < dataList.length; j++) {
                var d = dataList[j]
                if (!d || d === item) continue
                var already = false
                if (kids) {
                    for (var k = 0; k < kids.length; k++) if (kids[k] === d) { already = true; break }
                }
                if (already) continue
                var rd = findByName(d, name)
                if (rd) return rd
            }
        }
        return null
    }

    // Host under test - per-screen fixed popup host.
    Bar.BarPopupHost {
        id: host
        screenWidth: 1000
        screenHeight: 900
        effectiveBarHeight: 48
        floatingMargin: 4
    }

    // Dummy pill to verify primary click/wheel paths remain available.
    Bar.BarPill {
        id: clickPill
        objectName: "testPill"
        hoverIntentEnabled: true
        width: 48
        height: 48
        property int clickCount: 0
        onClicked: clickCount++
    }

    // Real actionable widget instances expose their production input paths.
    Widgets.Volume { id: volumeWidget; visible: false }
    Widgets.Brightness { id: brightnessWidget; visible: false }
    Widgets.Media { id: mediaWidget; visible: false }
    Widgets.Notifications { id: notificationsWidget; visible: false }

    // Timers for async hover-bridge waits.
    Timer {
        id: keepOpenWait
        interval: Lazer.MotionTokens.fast + 50
        onTriggered: {
            root.check("bridge keeps open while popup hovered", host.open, true)
            // Now release both hovers and expect close.
            host.widgetHovered = false
            host.popupHovered = false
            closeWait.restart()
        }
    }

    Timer {
        id: closeWait
        interval: Lazer.MotionTokens.fast + 50
        onTriggered: {
            root.check("bridge closes after leaving both", host.open, false)
            // After close, proceed to callback verification.
            Qt.callLater(root.runCallbacks)
        }
    }

    // Geometry settle helper for y ordering checks.
    Timer {
        id: geometryWaitTop
        interval: 30
        onTriggered: root.checkTopDirection()
    }
    Timer {
        id: geometryWaitBottom
        interval: 30
        onTriggered: root.checkBottomDirection()
    }
    Timer {
        id: edgeWaitLeft
        interval: 20
        onTriggered: root.checkEdgeLeft()
    }
    Timer {
        id: edgeWaitRight
        interval: 20
        onTriggered: root.checkEdgeRight()
    }

    // Keep reference to edge test intent.
    property var _edgeLeftAnchor: 0
    property var _edgeRightAnchor: 0

    Component.onCompleted: Qt.callLater(root.run)

    function run() {
        // Step 1: top bar direction.
        var intentTop = {
            widgetId: "volume",
            instanceKey: "volume:0",
            title: "Volume",
            iconSource: Qt.resolvedUrl("modules/bar/icons/volume.svg"),
            summary: "45%",
            actionKind: "volume",
            anchorX: 400,
            screenWidth: 1000,
            screenHeight: 900,
            effectiveBarHeight: 48,
            floatingMargin: 4,
            barPosition: "top",
            payload: { volume: 0.5, muted: false, volumeService: ({ setSinkVolume: function(){}, toggleSinkMute: function(){} }), onVolumeChanged: function(){}, onToggleMute: function(){} }
        }
        host.widgetHovered = true
        host.showIntent(intentTop)
        // Allow bindings to settle, then check geometry.
        geometryWaitTop.restart()
    }

    function checkTopDirection() {
        root.check("top bar direction is down", host.direction, "down")
        root.check("TwoLayerPopup direction Down for top bar", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Down)
        // Sidebar before content when down.
        var sidebarY = host.popupItem.sidebarLayer.y
        var contentY = host.popupItem.contentLayer.y
        root.checkTrue("top: content y greater than identity y", contentY > sidebarY)
        root.check("top: sidebar y is 0", sidebarY, 0)
        root.checkTrue("top: content y is sidebar height +1", contentY === host.popupItem.sidebarLayer.height + 1)
        root.check("top: popup absolute y below bar", host.popupContainerItem.y, 52)
        root.checkTrue("top: popup absolute placement stays inside screen",
                host.popupContainerItem.y >= 52
                && host.popupContainerItem.y + host.popupContainerItem.height <= host.activeScreenHeight)

        // Check identity/actions binding for top intent.
        var identity = findByName(host.popupItem, "popupIdentity")
        root.checkTrue("identity bound to host intent", identity !== null)
        if (identity) {
            root.check("identity title matches intent", identity.title, "Volume")
            root.check("identity summary matches intent", identity.summary, "45%")
        }
        var actions = findByName(host.popupItem, "popupActions")
        root.checkTrue("actions bound to host intent", actions !== null)
        if (actions) {
            root.check("actions kind matches intent", actions.actionKind, "volume")
        }

        // Next: bottom bar direction - update same popup instance.
        var intentBottom = {
            widgetId: "tray",
            instanceKey: "tray:2",
            title: "My App",
            iconSource: Qt.resolvedUrl("modules/lazerbar/icons/apps.svg"),
            summary: "3 items",
            actionKind: "tray",
            anchorX: 500,
            screenWidth: 1000,
            screenHeight: 900,
            effectiveBarHeight: 56,
            floatingMargin: 10,
            barPosition: "bottom",
            payload: { trayModel: ({ activate: function(){}, secondaryActivate: function(){} }), onActivate: function(){}, onSecondaryActivate: function(){} }
        }
        host.showIntent(intentBottom)
        root.check("same popup stays open after intent swap", host.open, true)
        root.check("anchor updated after tray swap", host.anchorX, 500)
        root.check("screen width updated in place", host.activeScreenWidth, 1000)
        root.check("screen height updated in place", host.activeScreenHeight, 900)
        root.check("bar height updated in place", host.activeBarHeight, 56)
        root.check("floating margin updated in place", host.activeFloatingMargin, 10)
        // Verify intent updated in place.
        root.check("intent title updated to tray", host.intent.title, "My App")
        geometryWaitBottom.restart()
    }

    function checkBottomDirection() {
        root.check("bottom bar direction is up", host.direction, "up")
        root.check("TwoLayerPopup direction Up for bottom bar", host.popupItem.direction, Lazer.TwoLayerPopup.Direction.Up)
        var sidebarY = host.popupItem.sidebarLayer.y
        var contentY = host.popupItem.contentLayer.y
        root.checkTrue("bottom: identity y greater than content y", sidebarY > contentY)
        root.check("bottom: content y is 0", contentY, 0)
        root.checkTrue("bottom: sidebar y is content height +1", sidebarY === host.popupItem.contentLayer.height + 1)
        root.check("orientation is Vertical", host.popupItem.orientation, Lazer.TwoLayerPopup.Orientation.Vertical)
        root.check("bottom: popup absolute y above bar",
                host.popupContainerItem.y,
                Math.max(0, host.activeScreenHeight - host.activeBarHeight
                    - host.activeFloatingMargin - host.popupContainerItem.height))
        root.check("bottom: popup absolute bottom at bar gap",
                host.popupContainerItem.y + host.popupContainerItem.height,
                host.activeScreenHeight - host.activeBarHeight - host.activeFloatingMargin)

        // Edge anchor left.
        var intentLeft = {
            widgetId: "volume",
            instanceKey: "volume:0",
            title: "LeftEdge",
            iconSource: Qt.resolvedUrl("modules/bar/icons/volume.svg"),
            summary: "edge",
            actionKind: "volume",
            anchorX: 2,
            screenWidth: 1000,
            barPosition: "top",
            payload: { volume: 0.5 }
        }
        host.showIntent(intentLeft)
        edgeWaitLeft.restart()
    }

    function checkEdgeLeft() {
        var w = host.popupContainerItem.width
        var x = host.popupContainerItem.x
        var expectedLeft = BarHoverLogic.clampAnchor(2, w, 1000, 8)
        root.check("left edge popup remains inside screen width", x, expectedLeft)
        root.checkTrue("left edge x >= margin", x >= 8)
        root.checkTrue("left edge popup inside screen", x + w <= 1000 - 8 + 0.5)
        // Check identity still reflects left edge intent.
        var identity = findByName(host.popupItem, "popupIdentity")
        if (identity) root.check("left edge identity title updated", identity.title, "LeftEdge")

        // Edge anchor right.
        var intentRight = {
            widgetId: "volume",
            instanceKey: "volume:0",
            title: "RightEdge",
            iconSource: Qt.resolvedUrl("modules/bar/icons/volume.svg"),
            summary: "edge",
            actionKind: "volume",
            anchorX: 990,
            screenWidth: 1000,
            barPosition: "top",
            payload: { volume: 0.5 }
        }
        host.showIntent(intentRight)
        edgeWaitRight.restart()
    }

    function checkEdgeRight() {
        var w = host.popupContainerItem.width
        var x = host.popupContainerItem.x
        var expectedRight = BarHoverLogic.clampAnchor(990, w, 1000, 8)
        root.check("right edge popup remains inside screen width", x, expectedRight)
        root.checkTrue("right edge x + width <= screen - margin", x + w <= 1000 - 8 + 0.5)
        root.checkTrue("right edge x >= margin", x >= 8)
        // Verify same popup instance not overlapping - still single host.
        root.check("still single host open after edge anchors", host.open, true)
        var identity2 = findByName(host.popupItem, "popupIdentity")
        if (identity2) root.check("right edge identity title updated", identity2.title, "RightEdge")

        // Tray in-place update: hovered tray icon changes.
        var trayA = {
            widgetId: "tray",
            instanceKey: "tray:0",
            title: "App A",
            iconSource: Qt.resolvedUrl("modules/lazerbar/icons/apps.svg"),
            summary: "A",
            actionKind: "tray",
            anchorX: 200,
            screenWidth: 1000,
            barPosition: "top",
            payload: { trayModel: ({ activate: function(){}, secondaryActivate: function(){} }), onActivate: function(){}, onSecondaryActivate: function(){} }
        }
        host.showIntent(trayA)
        root.check("tray A intent set", host.intent.title, "App A")
        var trayB = {
            widgetId: "tray",
            instanceKey: "tray:0",
            title: "App B",
            iconSource: Qt.resolvedUrl("modules/lazerbar/icons/apps.svg"),
            summary: "B",
            actionKind: "tray",
            anchorX: 400,
            screenWidth: 1000,
            barPosition: "top",
            payload: { trayModel: ({ activate: function(){}, secondaryActivate: function(){} }), onActivate: function(){}, onSecondaryActivate: function(){} }
        }
        host.showIntent(trayB)
        root.check("tray in-place update keeps same popup open", host.open, true)
        root.check("tray intent updated to App B without new window", host.intent.title, "App B")
        root.check("tray anchor updated in place", host.anchorX, 400)
        var trayIdentity = findByName(host.popupItem, "popupIdentity")
        if (trayIdentity) root.check("tray identity reflects updated icon", String(trayIdentity.iconSource), String(Qt.resolvedUrl("modules/lazerbar/icons/apps.svg")))

        // Start hover bridge sequence.
        Qt.callLater(root.runHoverBridge)
    }

    function runHoverBridge() {
        // Ensure open state for bridge test.
        var bridgeIntent = {
            widgetId: "volume",
            instanceKey: "volume:0",
            title: "Volume",
            iconSource: Qt.resolvedUrl("modules/bar/icons/volume.svg"),
            summary: "bridge",
            actionKind: "volume",
            anchorX: 300,
            screenWidth: 1000,
            barPosition: "top",
            payload: { volume: 0.5 }
        }
        host.showIntent(bridgeIntent)
        host.widgetHovered = true
        host.popupHovered = false
        root.check("bridge: open after widget hover", host.open, true)

        // Move from widget to popup: widget leaves, popup entered.
        host.widgetHovered = false
        host.popupHovered = true
        host.requestClose()
        keepOpenWait.restart()
    }

    function runCallbacks() {
        // Representative callbacks: volume, brightness, media, notifications, tray.

        if (!root._mediaReactiveVerified) {
            // Volume
            var volCalls = 0
            var volMuteCalls = 0
            var volIntent = {
            widgetId: "volume",
            instanceKey: "volume:0",
            title: "Volume",
            iconSource: Qt.resolvedUrl("modules/bar/icons/volume.svg"),
            summary: "50%",
            actionKind: "volume",
            anchorX: 300,
            screenWidth: 1000,
            barPosition: "top",
            payload: {
                volume: 0.5,
                muted: false,
                onVolumeChanged: function(v){ volCalls++ },
                onToggleMute: function(){ volMuteCalls++ }
            }
            }
            host.showIntent(volIntent)
            host.widgetHovered = true
            var actions = findByName(host.popupItem, "popupActions")
            root.checkTrue("volume actions found", actions !== null)
            if (actions) {
                // Trigger via direct handler.
                actions.handleVolumeValue(0.77)
                root.check("volume callback fires once", volCalls, 1)
                actions.handleToggleMute()
                root.check("volume mute callback fires once", volMuteCalls, 1)
                // Also verify slider exists.
                var volSlider = findByName(actions, "volumeSlider")
                root.checkTrue("volume slider exists", volSlider !== null)
                root.checkTrue("volume slider real track handler exists",
                        findByName(volSlider, "sliderTrackTap") !== null)
                root.checkTrue("volume slider real mute handler exists",
                        findByName(volSlider, "sliderMuteTap") !== null)
            }

            // Brightness
            var brightCalls = 0
            var brightIntent = {
            widgetId: "brightness",
            instanceKey: "brightness:0",
            title: "Brightness",
            iconSource: Qt.resolvedUrl("modules/bar/icons/brightness.svg"),
            summary: "80%",
            actionKind: "brightness",
            anchorX: 320,
            screenWidth: 1000,
            barPosition: "top",
            payload: { brightness: 0.8, onBrightnessChanged: function(v){ brightCalls++ } }
            }
            host.showIntent(brightIntent)
            actions = findByName(host.popupItem, "popupActions")
            root.checkTrue("brightness actions found", actions !== null)
            if (actions) {
                actions.handleBrightnessValue(0.33)
                root.check("brightness callback fires once", brightCalls, 1)
                var brightSlider = findByName(actions, "brightnessSlider")
                root.checkTrue("brightness slider exists", brightSlider !== null)
                // Verify brightness hides mute control.
                if (brightSlider) root.check("brightness hides mute", brightSlider.showMute, false)
                root.checkTrue("brightness slider real track handler exists",
                        findByName(brightSlider, "sliderTrackTap") !== null)
            }
        }

        if (!root._mediaReactiveVerified) {
            // Media: keep a reactive source in the payload so progress changes
            // update the existing popup content without replacing the intent.
            var mediaPrev = 0, mediaPlay = 0, mediaNextCount = 0
            var fakeMediaSource = Qt.createQmlObject('import QtQuick; QtObject { property int positionMs: 65000; property int lengthMs: 180000 }', root, "fakePopupMediaSource")
            var mediaIntent = {
            widgetId: "media",
            instanceKey: "media:0",
            title: "Media Title",
            iconSource: Qt.resolvedUrl("modules/lazerbar/icons/music.svg"),
            summary: "Artist",
            actionKind: "media",
            anchorX: 340,
            screenWidth: 1000,
            barPosition: "top",
            payload: {
                mediaControlService: fakeMediaSource,
                onPrevious: function(){ mediaPrev++ },
                onPlayPause: function(){ mediaPlay++ },
                onNext: function(){ mediaNextCount++ }
            }
            }
            host.showIntent(mediaIntent)
            actions = findByName(host.popupItem, "popupActions")
            root.checkTrue("media actions found", actions !== null)
            if (actions) {
                var progressText = findByName(actions, "mediaProgressText")
                root.checkTrue("media progress text exists", progressText !== null)
                if (progressText) {
                    root.check("media progress reflects payload", progressText.text, "1:05 / 3:00")
                    var sameActions = actions
                    fakeMediaSource.positionMs = 70000
                    Qt.callLater(function() {
                        root.check("media progress updates from reactive source", progressText.text, "1:10 / 3:00")
                        root.check("reactive media keeps same popup instance", findByName(host.popupItem, "popupActions") === sameActions, true)
                        actions.handleMediaPrevious()
                        root.check("media previous callback fires once", mediaPrev, 1)
                        actions.handleMediaPlayPause()
                        root.check("media playPause callback fires once", mediaPlay, 1)
                        actions.handleMediaNext()
                        root.check("media next callback fires once", mediaNextCount, 1)
                        root._mediaReactiveVerified = true
                        Qt.callLater(root.runCallbacks)
                    })
                    return
                }
            }
        }

        if (root._mediaReactiveVerified) {
            root._mediaReactiveVerified = false
            actions = findByName(host.popupItem, "popupActions")
            root.checkTrue("media previous real TapHandler exists", findByName(actions, "mediaPrevTap") !== null)
            root.checkTrue("media playPause real TapHandler exists", findByName(actions, "mediaPlayPauseTap") !== null)
            root.checkTrue("media next real TapHandler exists", findByName(actions, "mediaNextTap") !== null)
        }

        // Notifications
        var notifToggle = 0, notifClear = 0
        var notifIntent = {
            widgetId: "notifications",
            instanceKey: "notifications:0",
            title: "Notifications",
            iconSource: Qt.resolvedUrl("modules/lazerbar/icons/bell.svg"),
            summary: "2 unread",
            actionKind: "notifications",
            anchorX: 360,
            screenWidth: 1000,
            barPosition: "top",
            payload: { dndEnabled: false, onToggleDnd: function(){ notifToggle++ }, onMarkAllRead: function(){ notifClear++ } }
        }
        host.showIntent(notifIntent)
        actions = findByName(host.popupItem, "popupActions")
        root.checkTrue("notifications actions found", actions !== null)
        if (actions) {
            root.checkTrue("notification DND real TapHandler exists", findByName(actions, "notificationDndTap") !== null)
            root.checkTrue("notification clear real TapHandler exists", findByName(actions, "notificationClearTap") !== null)
            actions.handleToggleDnd()
            root.check("notification toggle callback fires once", notifToggle, 1)
            actions.handleClearNotifications()
            root.check("notification clear callback fires once", notifClear, 1)
        }

        // Tray
        var trayAct = 0, traySec = 0
        var trayIntent = {
            widgetId: "tray",
            instanceKey: "tray:0",
            title: "Tray App",
            iconSource: Qt.resolvedUrl("modules/lazerbar/icons/apps.svg"),
            summary: "Tray",
            actionKind: "tray",
            anchorX: 380,
            screenWidth: 1000,
            barPosition: "top",
            payload: { onActivate: function(){ trayAct++ }, onSecondaryActivate: function(){ traySec++ } }
        }
        host.showIntent(trayIntent)
        actions = findByName(host.popupItem, "popupActions")
        root.checkTrue("tray actions found", actions !== null)
        if (actions) {
            root.checkTrue("tray activate real TapHandler exists", findByName(actions, "trayActivateTap") !== null)
            root.checkTrue("tray secondary real TapHandler exists", findByName(actions, "traySecondaryTap") !== null)
            actions.handleTrayActivate()
            root.check("tray activate callback fires once", trayAct, 1)
            actions.handleTraySecondary()
            root.check("tray secondary callback fires once", traySec, 1)
        }

        // Primary widget click/wheel paths remain available.
        // Verify BarPill click still works while hover intent enabled.
        var clickBefore = clickPill.clickCount
        clickPill.clicked()
        root.check("primary widget click path remains available", clickPill.clickCount, clickBefore + 1)
        root.checkTrue("pill hoverIntentEnabled does not disable hoverable", clickPill.hoverable)

        // Verify WheelHandler still attached on widgets (static check via lint already) -
        // here we just assert that host does not block widget hover.
        root.checkTrue("host still exposes widgetHovered property", host.widgetHovered !== undefined)
        root.checkTrue("volume real WheelHandler path exists", findByName(volumeWidget, "volumeWheelHandler") !== null)
        root.checkTrue("brightness real WheelHandler path exists", findByName(brightnessWidget, "brightnessWheelHandler") !== null)
        root.checkTrue("media real WheelHandler path exists", findByName(mediaWidget, "mediaWheelHandler") !== null)
        root.checkTrue("notifications real click path exists", findByName(notificationsWidget, "pillPrimaryTapHandler") !== null)

        root.finish()
    }
}
