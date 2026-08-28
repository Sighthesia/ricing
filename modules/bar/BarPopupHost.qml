import QtQuick
import Quickshell
import "../lazerbar"
import "./BarHoverLogic.js" as BarHoverLogic

// Per-screen fixed hover popup host with stable PanelWindow geometry.
// Keeps the layer-shell window size fixed; only the inner TwoLayerPopup
// animates via revealProgress. Hover bridge lives in open/close timers.
PanelWindow {
    id: root

    // Intent payload from the hovered widget.
    property var intent: null
    property bool open: false
    property bool widgetHovered: false
    property bool popupHovered: false
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

    readonly property real activeScreenWidth: intentScreenWidth > 0 ? intentScreenWidth : screenWidth
    readonly property real activeScreenHeight: intentScreenHeight > 0 ? intentScreenHeight : screenHeight
    readonly property real activeBarHeight: intentBarHeight > 0 ? intentBarHeight : effectiveBarHeight
    readonly property real activeFloatingMargin: intentFloatingMargin >= 0 ? intentFloatingMargin : floatingMargin

    // Expose the two-layer slots generically; host owns only the surface.
    readonly property alias sidebarData: popup.sidebarData
    readonly property alias contentData: popup.contentData
    readonly property alias popupItem: popup
    readonly property alias popupContainerItem: popupContainer

    signal actionRequested(string action)
    signal closeRequested()

    function updateIntent(intentObj) {
        if (!intentObj)
            return
        root.intent = intentObj
        root.anchorX = Number(intentObj.anchorX)
        if (!isFinite(root.anchorX))
            root.anchorX = 0
        var sw = Number(intentObj.screenWidth)
        if (isFinite(sw) && sw > 0)
            root.intentScreenWidth = sw
        else
            root.intentScreenWidth = 0
        var sh = Number(intentObj.screenHeight)
        root.intentScreenHeight = isFinite(sh) && sh > 0 ? sh : 0
        var barHeight = Number(intentObj.effectiveBarHeight)
        root.intentBarHeight = isFinite(barHeight) && barHeight > 0 ? barHeight : 0
        var margin = Number(intentObj.floatingMargin)
        root.intentFloatingMargin = isFinite(margin) && margin >= 0 ? margin : -1
        var pos = intentObj.barPosition !== undefined ? String(intentObj.barPosition) : "top"
        root.direction = BarHoverLogic.popupDirection(pos)
        root.open = true
        cancelClose()
        clearIntentTimer.stop()
        // Drive the two-layer reveal forward; the internal staggered
        // opacity/offset contracts stay inside TwoLayerPopup.
        popup.visible = true
        popup.revealProgress = 1
    }

    function showIntent(intentObj) {
        updateIntent(intentObj)
    }

    function requestClose() {
        if (closeTimer.running)
            return
        closeTimer.start()
    }

    function cancelClose() {
        closeTimer.stop()
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
    visible: true

    // Close after MotionTokens.fast if both hover owners are gone.
    Timer {
        id: closeTimer
        interval: MotionTokens.fast
        onTriggered: {
            if (BarHoverLogic.shouldClose(root.widgetHovered, root.popupHovered, true)) {
                root.open = false
                root.closeRequested()
                popup.revealProgress = 0
                clearIntentTimer.restart()
            }
        }
    }

    // Clear the intent only after the exit reveal has finished so the
    // fading layers remain intact during the staggered fade.
    Timer {
        id: clearIntentTimer
        interval: popup.revealDuration + 40
        onTriggered: {
            if (!root.open)
                root.intent = null
        }
    }

    // Keep popupHovered in sync via non-blocking observation; widgetHovered
    // is driven by the external owner (BarContent/widget HoverHandler).
    onOpenChanged: {
        if (!open) {
            // Ensure the hover flag does not stick when the surface hides.
            // The widget side is owned externally and stays as-is.
        } else {
            popup.visible = true
            popup.revealProgress = 1
        }
    }

    // Fixed outer host; inner popup is clamped horizontally.
    Item {
        id: popupContainer
        objectName: "popupContainer"
        // Size follows both slots so clamping uses the rendered surface bounds.
        width: Math.max(popup.sidebarLayer.width, popup.contentLayer.width, 240)
        height: popup.sidebarLayer.height + popup.contentLayer.height + 1
        x: BarHoverLogic.clampAnchor(root.anchorX, width, root.activeScreenWidth, 8)
        y: root.direction === "down"
            ? root.activeBarHeight + root.activeFloatingMargin
            : Math.max(0, root.activeScreenHeight - root.activeBarHeight
                - root.activeFloatingMargin - height)
        visible: popup.visible

        // Non-blocking hover bridge on the popup surface.
        HoverHandler {
            id: popupHoverHandler
            blocking: false
            onHoveredChanged: root.popupHovered = hovered
        }

        // Two-layer surface; vertical orientation with direction driven by
        // the bar position (top -> Down, bottom -> Up).
        TwoLayerPopup {
            id: popup
            orientation: TwoLayerPopup.Orientation.Vertical
            direction: root.direction === "up" ? TwoLayerPopup.Direction.Up : TwoLayerPopup.Direction.Down
            width: popupContainer.width
            height: popupContainer.height
            revealProgress: 1
            contentDelay: MotionTokens.settingsContentDelay
            visible: root.open || revealProgress > 0

            // Identity layer bound to the current intent; updates in place when
            // the hovered tray delegate changes so no overlapping windows appear.
            sidebarData: BarPopupIdentity {
                objectName: "popupIdentity"
                title: root.intent ? (root.intent.title || "") : ""
                iconSource: root.intent ? (root.intent.iconSource || "") : ""
                summary: root.intent ? (root.intent.summary || "") : ""
                hostWidth: 260
            }

            // Action layer bound to the intent's kind and payload.
            contentData: BarPopupActions {
                objectName: "popupActions"
                actionKind: root.intent ? (root.intent.actionKind || "") : ""
                payload: root.intent ? root.intent.payload : null
            }
        }
    }
}
