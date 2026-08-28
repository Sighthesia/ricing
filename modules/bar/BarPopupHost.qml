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
    property int effectiveBarHeight: 48
    property int floatingMargin: 4

    // Expose the two-layer slots generically; host owns only the surface.
    readonly property alias sidebarData: popup.sidebarData
    readonly property alias contentData: popup.contentData
    readonly property alias popupItem: popup

    signal actionRequested(string action)
    signal closeRequested()

    function showIntent(intentObj) {
        if (!intentObj)
            return
        root.intent = intentObj
        root.anchorX = Number(intentObj.anchorX)
        if (!isFinite(root.anchorX))
            root.anchorX = 0
        var sw = Number(intentObj.screenWidth)
        if (isFinite(sw) && sw > 0)
            root.screenWidth = sw
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
    implicitHeight: screen ? screen.height : 600
    // Anchor to the same edge as the bar and offset by the bar's effective
    // height plus floating margin so the popup docks directly beneath/above it.
    anchors {
        top: root.direction === "down"
        bottom: root.direction === "up"
        left: true
        right: true
    }
    margins {
        top: root.direction === "down" ? root.effectiveBarHeight + root.floatingMargin : 0
        bottom: root.direction === "up" ? root.effectiveBarHeight + root.floatingMargin : 0
        left: 0
        right: 0
    }
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
        // Width/height follow the TwoLayerPopup's implicit content size.
        width: popup.implicitWidth > 0 ? popup.implicitWidth : (popup.width > 0 ? popup.width : 240)
        height: popup.implicitHeight > 0 ? popup.implicitHeight : (popup.height > 0 ? popup.height : 80)
        x: BarHoverLogic.clampAnchor(root.anchorX, width, root.screenWidth, 8)
        y: 0
        visible: popup.visible

        // Non-blocking hover bridge on the popup surface.
        HoverHandler {
            id: popupHoverHandler
            onHoveredChanged: root.popupHovered = hovered
        }

        // Two-layer surface; vertical orientation with direction driven by
        // the bar position (top -> Down, bottom -> Up).
        TwoLayerPopup {
            id: popup
            orientation: TwoLayerPopup.Orientation.Vertical
            direction: root.direction === "up" ? TwoLayerPopup.Direction.Up : TwoLayerPopup.Direction.Down
            revealProgress: 1
            contentDelay: MotionTokens.settingsContentDelay
            visible: root.open || revealProgress > 0
            // Size is driven by slot content; keep empty until Task 3 adapters.
        }
    }
}
