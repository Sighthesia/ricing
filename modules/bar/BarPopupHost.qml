import QtQuick
import Quickshell
import Quickshell.Wayland
import "../lazerbar"
import "../../services" as Services
import "./BarHoverLogic.js" as BarHoverLogic

// Per-screen fixed hover popup host with stable PanelWindow geometry.
// Keeps the layer-shell window size fixed; only the inner TwoLayerPopup
// animates via revealProgress. Hover bridge lives in open/close timers.
PanelWindow {
    id: root

    // Name the surface so compositor diagnostics can identify it.
    WlrLayershell.namespace: "afloat-popup"
    // Keep the full-screen owner below the bar and settings owners.
    // The mask limits input to the small active popup rectangle.
    WlrLayershell.layer: WlrLayer.Top

    // Intent payload from the hovered widget.
    property var intent: null
    property var currentIntent: null
    property var pendingIntent: null
    property int transitionSerial: 0
    property int replacementSerial: 0
    property bool replacingContent: false
    property real contentOpacity: 1
    readonly property bool closeTimerRunning: closeTimer.running
    readonly property bool contentInteractive:
        contentOpacity > 0.99 && popup.interactable
    property bool open: false
    property bool widgetHovered: false
    property bool popupHovered: false
    // Keep the full-screen layer-shell surface absent until a popup owns it.
    property bool surfaceActive: false
    property string direction: "down"
    property real anchorX: 0
    property real screenWidth: 1920
    property real screenHeight: 1080
    property int effectiveBarHeight: 48
    property int floatingMargin: 4
    property real intentScreenWidth: 0
    property real intentScreenHeight: 0
    property real intentBarHeight: 0
    property real intentFloatingMargin: -1
    property bool popupHoverWasActive: false

    property real displayX: 0
    property real displayY: 0
    property real displayWidth: 260
    property real displayHeight: 1
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 260
    property real targetHeight: 1
    // Stable travel distance for the current reveal/exit cycle.
    property real revealDistance: 1
    // Keep the reveal viewport large enough while displayed geometry morphs.
    readonly property real revealViewportHeight: Math.max(root.displayHeight,
            root.targetHeight, root.revealDistance, 1)

    readonly property real activeScreenWidth: intentScreenWidth > 0 ? intentScreenWidth : screenWidth
    readonly property real activeScreenHeight: intentScreenHeight > 0 ? intentScreenHeight : screenHeight
    readonly property real activeBarHeight: intentBarHeight > 0 ? intentBarHeight : effectiveBarHeight
    readonly property real activeFloatingMargin: intentFloatingMargin >= 0 ? intentFloatingMargin : floatingMargin

    // Expose the two-layer slots generically; host owns only the surface.
    readonly property alias sidebarData: popup.sidebarData
    readonly property alias contentData: popup.contentData
    readonly property alias popupItem: popup
    readonly property alias popupContainerItem: popupContainer
    readonly property alias contextActions: contextPopupActions

    signal actionRequested(string action)
    signal closeRequested()

    // Vertical popup layers slide from the bar using a stable travel distance;
    // the disabled internal clip keeps the full layers visible while moving.
    readonly property real slideOffset: root.direction === "up"
            ? root.revealDistance + 1 : -(root.revealDistance + 1)

    function startReveal(target) {
        revealMotion.stop()
        if (Math.abs(popup.revealProgress - target) < 0.001) {
            popup.revealProgress = target
            return
        }
        revealMotion.duration = MotionTokens.reducedMotion
                ? MotionTokens.fast : popup.revealDuration
        revealMotion.easing.type = target >= 1 ? Easing.OutQuint : Easing.InQuad
        revealMotion.to = target
        revealMotion.restart()
    }

    // Reuse the settings-panel diagnostics channel so one IPC switch turns on
    // both surfaces; every popup decision is logged without adding an owner.
    readonly property bool debugEnabled: Services.SettingsService.hoverDebugEnabled
    property string _lastDebugSignature: ""

    function _debugRect(item) {
        if (!item)
            return { "x": 0, "y": 0, "width": 0, "height": 0 }
        return {
            "x": Math.round(Number(item.x) * 10) / 10, "y": Math.round(Number(item.y) * 10) / 10,
            "width": Math.max(0, Math.round(Number(item.width) * 10) / 10),
            "height": Math.max(0, Math.round(Number(item.height) * 10) / 10),
        }
    }

    function debugSnapshot() {
        return {
            "host": {
                "phase": root.open ? "open" : (root.surfaceActive ? "revealing" : "closed"),
                "surfaceActive": root.surfaceActive, "widgetHovered": root.widgetHovered,
                "popupHovered": root.popupHovered, "direction": root.direction,
                "windowVisible": root.visible, "windowRect": root._debugRect(root),
                "layer": Number(root.WlrLayershell.layer),
                "closeTimer": closeTimer.running, "clearTimer": clearIntentTimer.running,
            },
            "intent": root.intent ? {
                "widgetId": String(root.intent.widgetId || ""), "kind": String(root.intent.kind || ""),
                "actionKind": String(root.intent.actionKind || ""),
                "anchorX": Number(root.intent.anchorX),
            } : null,
            "container": { "rect": root._debugRect(popupContainer), "visible": popupContainer.visible },
            "popup": {
                "visible": popup.visible, "revealProgress": Number(popup.revealProgress),
                "sidebar": root._debugRect(popup.sidebarLayer),
                "content": root._debugRect(popup.contentLayer),
                "sidebarOpacity": Number(popup.sidebarLayer.opacity),
                "contentOpacity": Number(popup.contentLayer.opacity),
            },
        }
    }

    function debugLog(event, payload) {
        if (!root.debugEnabled)
            return
        var entry = Object.assign({ "event": event }, payload || ({}))
        var signature = JSON.stringify(entry)
        if (signature === root._lastDebugSignature)
            return
        root._lastDebugSignature = signature
        console.log("[afloat:PopupDebug]", signature)
    }

    function emitDebugSnapshot() {
        root.debugLog("snapshot", root.debugSnapshot())
    }

    // Poll only while diagnostics are enabled so no extra owner or timer runs live.
    Timer {
        interval: 120
        repeat: true
        running: root.debugEnabled
        onTriggered: root.emitDebugSnapshot()
    }

    onPopupHoveredChanged: {
        if (popupHoverWasActive && !popupHovered)
            requestClose()
        popupHoverWasActive = popupHovered
    }

    function updateIntent(intentObj) {
        if (!intentObj)
            return

        // A new intent revives the live host before replacement is evaluated.
        // This prevents a pending close from racing the single popup instance.
        cancelClose()
        var isOpen = root.open && root.currentIntent
        var isReplacement = isOpen && !root.sameIntent(root.currentIntent, intentObj)
        if (!isOpen) {
            root.invalidateContentTransition()
            root.currentIntent = intentObj
        } else if (isReplacement) {
            root.beginIntentReplacement(intentObj)
        } else {
            // Same instance updates (for example a tray delegate label or a
            // refreshed callback payload) stay live without a crossfade.
            root.invalidateContentTransition()
            root.currentIntent = intentObj
        }

        root.intent = intentObj
        var anchor = Number(intentObj.anchorX)
        if (isFinite(anchor) && anchor >= 0)
            root.anchorX = anchor
        var sw = Number(intentObj.screenWidth)
        if (isFinite(sw) && sw > 0)
            root.intentScreenWidth = sw
        var sh = Number(intentObj.screenHeight)
        if (isFinite(sh) && sh > 0)
            root.intentScreenHeight = sh
        var barHeight = Number(intentObj.effectiveBarHeight)
        if (isFinite(barHeight) && barHeight >= 0)
            root.intentBarHeight = barHeight
        var margin = Number(intentObj.floatingMargin)
        if (isFinite(margin) && margin >= 0)
            root.intentFloatingMargin = margin
        var pos = intentObj.barPosition !== undefined
                ? String(intentObj.barPosition).trim().toLowerCase() : ""
        if (pos === "top" || pos === "bottom")
            root.direction = BarHoverLogic.popupDirection(pos)
        root.updateTargetGeometry(intentObj)
        root.open = true
        root.surfaceActive = true
        clearIntentTimer.stop()
        root.debugLog("open", { "windowVisible": root.visible, "surfaceActive": true,
                                "direction": root.direction, "anchorX": root.anchorX })
    }

    function invalidateContentTransition() {
        contentFade.stop()
        root.transitionSerial += 1
        root.pendingIntent = null
        root.replacingContent = false
        root.contentOpacity = 1
    }

    function beginIntentReplacement(intentObj) {
        root.pendingIntent = intentObj
        root.transitionSerial += 1
        var serial = root.transitionSerial
        contentFade.stop()
        root.replacementSerial = serial
        if (MotionTokens.reducedMotion) {
            root.applyPendingIntent(serial)
            return
        }
        root.replacingContent = true
        contentFade.to = 0
        contentFade.restart()
    }

    function applyPendingIntent(serial) {
        // A natural close owns the exit window; replacement completion must not
        // resurrect content or install a target after the host starts closing.
        if (!root.open || serial !== root.transitionSerial || !root.pendingIntent)
            return

        var nextIntent = root.pendingIntent
        root.currentIntent = nextIntent
        root.intent = nextIntent
        root.pendingIntent = null
        root.replacingContent = false
        root.updateTargetGeometry(nextIntent)
        contentFade.to = 1
        if (MotionTokens.reducedMotion)
            root.contentOpacity = 1
        else
            contentFade.restart()
    }

    function sameIntent(left, right) {
        if (!left || !right)
            return false
        return String(left.widgetId || "") === String(right.widgetId || "")
            && String(left.instanceKey || "") === String(right.instanceKey || "")
            && String(left.kind || "hover") === String(right.kind || "hover")
            && String(left.actionKind || "") === String(right.actionKind || "")
    }

    function _intentNumber(intentObj, fieldName, fallback, minimum) {
        var value = Number(intentObj && intentObj[fieldName])
        return isFinite(value) && value >= minimum ? value : fallback
    }

    function anchorXForIntent(intentObj) {
        return _intentNumber(intentObj, "anchorX", root.anchorX, 0)
    }

    function activeScreenWidthForIntent(intentObj) {
        return _intentNumber(intentObj, "screenWidth", root.activeScreenWidth, 1)
    }

    function directionForIntent(intentObj) {
        var position = intentObj && intentObj.barPosition !== undefined
                ? String(intentObj.barPosition).trim().toLowerCase() : ""
        return position === "top" || position === "bottom"
                ? BarHoverLogic.popupDirection(position) : root.direction
    }

    function barHeightForIntent(intentObj) {
        return _intentNumber(intentObj, "effectiveBarHeight", root.activeBarHeight, 0)
    }

    function floatingMarginForIntent(intentObj) {
        return _intentNumber(intentObj, "floatingMargin", root.activeFloatingMargin, 0)
    }

    function screenHeightForIntent(intentObj) {
        return _intentNumber(intentObj, "screenHeight", root.activeScreenHeight, 1)
    }

    function popupHeightForIntent(intentObj) {
        if (!intentObj)
            return 1
        var height = String(intentObj.kind || "") === "context"
                ? contextPopupActions.implicitHeight : popupActions.implicitHeight
        return isFinite(Number(height)) && Number(height) > 0 ? Number(height) : 1
    }

    function targetGeometryFor(intentObj, width, height) {
        var left = BarHoverLogic.clampAnchor(anchorXForIntent(intentObj) - width / 2,
                width, activeScreenWidthForIntent(intentObj), 8)
        var top = directionForIntent(intentObj) === "down"
                ? barHeightForIntent(intentObj) + floatingMarginForIntent(intentObj)
                : Math.max(0, screenHeightForIntent(intentObj) - barHeightForIntent(intentObj)
                    - floatingMarginForIntent(intentObj) - height)
        return { x: left, y: top, width: width, height: height }
    }

    function updateTargetGeometry(intentObj, immediate) {
        var width = Math.max(240, popup.sidebarLayer.implicitWidth || 260,
                popup.contentLayer.implicitWidth || 260)
        var displayedIntent = root.currentIntent || intentObj
        var height = Number(popup.sidebarLayer.implicitHeight) + popupHeightForIntent(displayedIntent) + 1
        if (!isFinite(width) || width < 0)
            width = 240
        if (!isFinite(height) || height < 1)
            height = 1
        var geometry = targetGeometryFor(intentObj, width, height)
        root.targetWidth = geometry.width
        root.targetHeight = geometry.height
        root.retargetGeometry(intentObj, immediate === true || !root.open)
    }

    function retargetGeometry(intentObj, immediate) {
        var geometry = targetGeometryFor(intentObj || root.currentIntent || root.intent,
                root.targetWidth, root.targetHeight)
        root.targetX = geometry.x
        root.targetY = geometry.y
        if (immediate || MotionTokens.reducedMotion) {
            xMotion.stop()
            yMotion.stop()
            widthMotion.stop()
            heightMotion.stop()
            root.displayX = root.targetX
            root.displayY = root.targetY
            root.displayWidth = root.targetWidth
            root.displayHeight = root.targetHeight
            return
        }
        xMotion.to = root.targetX
        yMotion.to = root.targetY
        widthMotion.to = root.targetWidth
        heightMotion.to = root.targetHeight
        xMotion.restart()
        yMotion.restart()
        widthMotion.restart()
        heightMotion.restart()
    }

    function showIntent(intentObj) {
        updateIntent(intentObj)
    }

    function requestClose() {
        if (closeTimer.running)
            return
        // A close request cancels replacement immediately. Keep current/root
        // intent alive for the exit reveal, but never let old fade callbacks
        // install content after the close has begun.
        if (root.replacingContent || root.pendingIntent)
            root.invalidateContentTransition()
        root.debugLog("closePending", { "widgetHovered": root.widgetHovered, "popupHovered": root.popupHovered })
        closeTimer.start()
    }

    function cancelClose() {
        closeTimer.stop()
    }

    // Release the popup owner before another overlay claims the screen.
    function dismissImmediately() {
        root.debugLog("dismissed", { "open": root.open, "surfaceActive": root.surfaceActive })
        closeTimer.stop()
        clearIntentTimer.stop()
        revealMotion.stop()
        root.invalidateContentTransition()
        popup.revealProgress = 0
        root.open = false
        root.widgetHovered = false
        root.popupHovered = false
        root.intent = null
        root.currentIntent = null
        root.pendingIntent = null
        root.replacingContent = false
        root.transitionSerial += 1
        root.surfaceActive = false
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Keep the layer-shell surface fixed at screen size; only the inner
    // clipped content animates so per-frame resizes never cross a protocol
    // commit boundary.
    implicitWidth: screen ? screen.width : root.screenWidth
    implicitHeight: screen ? screen.height : root.screenHeight
    // Keep the host full-screen; the inner popup owns its absolute bar-adjacent
    // placement so an upward popup can occupy the space above a bottom bar.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins { top: 0; bottom: 0; left: 0; right: 0 }
    // No input when closed; the window otherwise masks only the popup.
    mask: Region { item: root.open ? popupContainer : null }
    // Do not keep a full-screen transparent surface above the settings window
    // when no bar popup is open or completing its reveal.
    visible: root.surfaceActive

    // Close after MotionTokens.fast if both hover owners are gone.
    Timer {
        id: closeTimer
        interval: MotionTokens.fast
        onTriggered: {
            if (BarHoverLogic.shouldClose(root.widgetHovered, root.popupHovered, true)) {
                root.debugLog("closed", { "revealProgress": Number(popup.revealProgress) })
                // Invalidate replacement callbacks, but retain both intents until
                // the exit reveal cleanup has completed.
                root.invalidateContentTransition()
                root.open = false
                root.closeRequested()
                clearIntentTimer.restart()
            }
        }
    }

    // Slide the stacked layers together; geometry is the only reveal channel.
    NumberAnimation {
        id: revealMotion
        target: popup
        property: "revealProgress"
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.settingsSidebarFade
    }

    // Serialize content replacement behind one short fade-out/fade-in channel.
    NumberAnimation {
        id: contentFade
        target: root
        property: "contentOpacity"
        duration: MotionTokens.fast
        easing.type: Easing.InOutQuad
        onFinished: {
            if (root.contentOpacity <= 0.001 && root.replacingContent)
                root.applyPendingIntent(root.replacementSerial)
        }
    }

    // Animate displayed popup position independently from its retargetable goal.
    NumberAnimation {
        id: xMotion
        target: root
        property: "displayX"
        duration: MotionTokens.reducedMotion ? 0 : MotionTokens.medium
        easing.type: Easing.OutQuint
    }

    // Animate the vertical placement without changing the fixed host surface.
    NumberAnimation {
        id: yMotion
        target: root
        property: "displayY"
        duration: MotionTokens.reducedMotion ? 0 : MotionTokens.medium
        easing.type: Easing.OutQuint
    }

    // Animate the popup width from its current displayed value.
    NumberAnimation {
        id: widthMotion
        target: root
        property: "displayWidth"
        duration: MotionTokens.reducedMotion ? 0 : MotionTokens.medium
        easing.type: Easing.OutQuint
    }

    // Animate content height while the outer PanelWindow stays screen-sized.
    NumberAnimation {
        id: heightMotion
        target: root
        property: "displayHeight"
        duration: MotionTokens.reducedMotion ? 0 : MotionTokens.medium
        easing.type: Easing.OutQuint
    }

    // Clear the intent only after the exit reveal has finished so the
    // fading layers remain intact during the staggered fade.
    Timer {
        id: clearIntentTimer
        interval: popup.revealDuration + 40
        onTriggered: {
            if (!root.open) {
                root.invalidateContentTransition()
                root.intent = null
                root.currentIntent = null
                root.surfaceActive = false
            }
        }
    }

    // Let current-intent bindings settle before starting the reveal. Without
    // this one event-loop turn, the first frame can use the menu's fallback
    // height and reveal only part of the measured content.
    Timer {
        id: revealStartTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.open && root.surfaceActive) {
                root.updateTargetGeometry(root.currentIntent, true)
                root.revealDistance = Math.max(root.targetHeight, root.displayHeight, 1)
                root.startReveal(1)
            }
        }
    }

    // Keep popupHovered in sync via non-blocking observation; widgetHovered
    // is driven by the external owner (BarContent/widget HoverHandler).
    onOpenChanged: {
        // Reveal is re-driven by the open state; visibility itself stays on
        // the surfaceActive binding so parents and children never read each
        // other's effective visibility (which deadlocks at false).
        if (open) {
            if (MotionTokens.reducedMotion) {
                revealStartTimer.stop()
                root.updateTargetGeometry(root.currentIntent, true)
                root.revealDistance = Math.max(root.targetHeight, root.displayHeight, 1)
                root.startReveal(1)
            } else {
                revealStartTimer.restart()
            }
        } else {
            revealStartTimer.stop()
            root.startReveal(0)
        }
    }

    // Fixed outer host; inner popup is clamped horizontally. The container is
    // a positioning wrapper and stays visible; the reveal item below gates
    // all painting, so no parent/child visibility chain is needed.
    Item {
        id: popupContainer
        objectName: "popupContainer"
        // Size follows both slots so clamping uses the rendered surface bounds.
        width: root.displayWidth
        height: root.displayHeight
        // Convert the producer's trigger center into the popup's left edge
        // before applying the existing screen-edge clamp contract.
        x: root.displayX
        y: root.displayY

        // Non-blocking hover bridge on the popup surface.
        HoverHandler {
            id: popupHoverHandler
            blocking: false
            onHoveredChanged: root.popupHovered = hovered
        }

            // Two-layer surface; vertical orientation with direction driven by
            // the bar position (top -> Down, bottom -> Up). The popup clip is
            // the bar edge, while the layers provide the slide motion.
            TwoLayerPopup {
                id: popup
                orientation: TwoLayerPopup.Orientation.Vertical
            clipVertical: false
                direction: root.direction === "up" ? TwoLayerPopup.Direction.Up : TwoLayerPopup.Direction.Down
                opening: root.open
                width: popupContainer.width
                height: popupContainer.height
                revealProgress: 0
                contentDelay: MotionTokens.settingsContentDelay
                animateLayerOpacity: false
            sidebarOffset: root.slideOffset
            contentOffset: root.slideOffset
            // Single source of truth: the reveal lives while the surface is
            // active, covering both the open state and the exit slide window.
            visible: root.surfaceActive

            // Identity layer bound to the current intent; updates in place when
            // the hovered tray delegate changes so no overlapping windows appear.
            sidebarData: BarPopupIdentity {
                objectName: "popupIdentity"
                title: root.currentIntent ? (root.currentIntent.title || "") : ""
                iconSource: root.currentIntent ? (root.currentIntent.iconSource || "") : ""
                summary: root.currentIntent ? (root.currentIntent.summary || "") : ""
                hostWidth: 260
            }

            // Keep both menu bodies in one content host so only the active
            // intent contributes to the popup height and visible surface.
            contentData: Item {
                 objectName: "popupContentSlot"
                 width: 260
                 implicitHeight: root.popupHeightForIntent(root.currentIntent)
                 height: implicitHeight
                 opacity: root.contentOpacity
                 enabled: root.contentInteractive
                 onImplicitHeightChanged: root.updateTargetGeometry(root.currentIntent)

                // Settings section-block surface under the action rows; the
                // darker cards float on it exactly like the settings panel.
                Rectangle {
                    objectName: "popupContentSurface"
                    x: 0
                    y: root.direction === "down" ? -1 : 0
                    width: parent.width
                    height: parent.height + 1
                    color: LazerTheme.settingsSection
                }

                // Action layer bound to the hovered widget intent.
                BarPopupActions {
                    id: popupActions
                    objectName: "popupActions"
                    anchors.fill: parent
                    actionKind: root.currentIntent && root.currentIntent.kind !== "context"
                            ? (root.currentIntent.actionKind || "") : "context"
                    payload: root.currentIntent ? root.currentIntent.payload : null
                }

                // Context actions reuse the same content owner and geometry.
                BarContextPopupActions {
                    id: contextPopupActions
                    objectName: "contextPopupActions"
                    anchors.fill: parent
                    actionKind: root.currentIntent && root.currentIntent.kind === "context" ? "context" : ""
                    widgetId: root.currentIntent ? (root.currentIntent.widgetId || "") : ""
                    instanceKey: root.currentIntent ? (root.currentIntent.instanceKey || "") : ""
                    section: root.currentIntent ? (root.currentIntent.section || "center") : "center"
                    hasSettings: root.currentIntent ? root.currentIntent.hasSettings === true : false
                    payload: root.currentIntent ? root.currentIntent.payload : null
                    onActionRequested: action => {
                        if (action === "close")
                            root.dismissImmediately()
                    }
                }
            }
        }
    }
}
