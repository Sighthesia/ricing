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
        root.surfaceActive = true
        cancelClose()
        clearIntentTimer.stop()
        // Drive the two-layer reveal forward; the internal staggered
        // opacity/offset contracts stay inside TwoLayerPopup. Visibility is
        // owned by the surfaceActive binding alone so no imperative write can
        // fight it (Item.visible reads effective visibility including parents).
        popup.revealProgress = 1
        root.debugLog("open", { "windowVisible": root.visible, "surfaceActive": true,
                                "direction": root.direction, "anchorX": root.anchorX })
    }

    function showIntent(intentObj) {
        updateIntent(intentObj)
    }

    function requestClose() {
        if (closeTimer.running)
            return
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
        root.open = false
        root.widgetHovered = false
        root.popupHovered = false
        root.intent = null
        root.surfaceActive = false
        popup.revealProgress = 0
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
            if (!root.open) {
                root.intent = null
                root.surfaceActive = false
            }
        }
    }

    // Keep popupHovered in sync via non-blocking observation; widgetHovered
    // is driven by the external owner (BarContent/widget HoverHandler).
    onOpenChanged: {
        if (!open) {
            // Ensure the hover flag does not stick when the surface hides.
            // The widget side is owned externally and stays as-is.
        } else {
            // Reveal is re-driven on every open; visibility itself stays on
            // the surfaceActive binding so parents and children never read
            // each other's effective visibility (which deadlocks at false).
            popup.revealProgress = 1
        }
    }

    // Fixed outer host; inner popup is clamped horizontally. The container is
    // a positioning wrapper and stays visible; the reveal item below gates
    // all painting, so no parent/child visibility chain is needed.
    Item {
        id: popupContainer
        objectName: "popupContainer"
        // Size follows both slots so clamping uses the rendered surface bounds.
        width: Math.max(popup.sidebarLayer.width, popup.contentLayer.width, 240)
        height: popup.sidebarLayer.height + popup.contentLayer.height + 1
        // Convert the producer's trigger center into the popup's left edge
        // before applying the existing screen-edge clamp contract.
        x: BarHoverLogic.clampAnchor(root.anchorX - width / 2,
                width, root.activeScreenWidth, 8)
        y: root.direction === "down"
            ? root.activeBarHeight + root.activeFloatingMargin
            : Math.max(0, root.activeScreenHeight - root.activeBarHeight
                - root.activeFloatingMargin - height)

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
            revealProgress: 0
            contentDelay: MotionTokens.settingsContentDelay
            // Single source of truth: the reveal lives while the surface is
            // active, covering both the open state and the exit fade window.
            visible: root.surfaceActive

            // Identity layer bound to the current intent; updates in place when
            // the hovered tray delegate changes so no overlapping windows appear.
            sidebarData: BarPopupIdentity {
                objectName: "popupIdentity"
                title: root.intent ? (root.intent.title || "") : ""
                iconSource: root.intent ? (root.intent.iconSource || "") : ""
                summary: root.intent ? (root.intent.summary || "") : ""
                hostWidth: 260
            }

            // Keep both menu bodies in one content host so only the active
            // intent contributes to the popup height and visible surface.
            contentData: Item {
                objectName: "popupContentSlot"
                width: 260
                implicitHeight: Math.max(popupActions.implicitHeight, contextPopupActions.implicitHeight)
                height: implicitHeight

                // Action layer bound to the hovered widget intent.
                BarPopupActions {
                    id: popupActions
                    objectName: "popupActions"
                    anchors.fill: parent
                    actionKind: root.intent && root.intent.kind !== "context"
                            ? (root.intent.actionKind || "") : "context"
                    payload: root.intent ? root.intent.payload : null
                }

                // Context actions reuse the same content owner and geometry.
                BarContextPopupActions {
                    id: contextPopupActions
                    objectName: "contextPopupActions"
                    anchors.fill: parent
                    actionKind: root.intent && root.intent.kind === "context" ? "context" : ""
                    widgetId: root.intent ? (root.intent.widgetId || "") : ""
                    instanceKey: root.intent ? (root.intent.instanceKey || "") : ""
                    section: root.intent ? (root.intent.section || "center") : "center"
                    hasSettings: root.intent ? root.intent.hasSettings === true : false
                    payload: root.intent ? root.intent.payload : null
                    onActionRequested: action => {
                        if (action === "close")
                            root.dismissImmediately()
                    }
                }
            }
        }
    }
}
