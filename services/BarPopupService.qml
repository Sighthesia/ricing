pragma Singleton
import QtQuick

// Hold shared open-state for hover-driven bar popups so a widget and the
// floating popup window can communicate without a parent relationship.
// Pure state only: open/close grace timers live in the popup host.
QtObject {
    id: root

    // Which popup kind is currently shown: "tray", "barmenu", "volume",
    // "brightness", "clock", "media", or "notifications". Empty while closed.
    property string kind: ""
    // Whether the popup surface should currently be shown.
    readonly property bool visible: kind !== ""
    // Bar-window-local X (both windows share horizontal margins) of the
    // hovered widget center; the host clamps and positions around it.
    property real anchorX: 0
    // Kind-specific payload, e.g. the tray item's QsMenuHandle.
    property var payload: null
    // True while the pointer is over the popup surface, so leaving the
    // widget does not close it.
    property bool pointerInPopup: false
    // Set when a widget asks for a close; the host confirms after its grace
    // window unless hover returns first.
    property bool closePending: false
    // TEMP DEBUG: last known pointer position inside the popup window.
    property string debugPoint: "-"
    // Suppress hover-driven re-open while another higher-priority surface
    // (for example a drag) owns the same area.
    property bool suppressHoverOpen: false

    // Open (or re-anchor) the popup for one kind. Idempotent: re-hovering
    // the same already-open payload only refreshes the anchor, so jitter at
    // the widget edge does not re-trigger the open animation. `force`
    // bypasses hover suppression so explicit intents (right-click menu)
    // stay reachable while hover popups are suppressed in layout mode.
    function open(popupKind, x, popupPayload, force) {
        if (suppressHoverOpen && !force)
            return
        if (kind === popupKind && visible && payload === popupPayload) {
            anchorX = x
            closePending = false
            return
        }
        // Anchor and payload before kind: flipping `kind` makes `visible`
        // true synchronously, and the host snapshots state in that same
        // instant -- it must never read the previous popup's anchor/payload.
        anchorX = x
        payload = popupPayload
        kind = popupKind
        pointerInPopup = false
        closePending = false
    }

    // A widget lost hover; defer to the host's grace timer unless the
    // pointer already moved onto the popup surface.
    function requestClose() {
        if (!visible || pointerInPopup)
            return
        closePending = true
    }

    // Cancel a pending close because hover returned to the widget or popup.
    function cancelClose() {
        closePending = false
    }

    function close() {
        kind = ""
        anchorX = 0
        payload = null
        pointerInPopup = false
        closePending = false
    }

    function closeAndSuppress() {
        close()
        suppressHoverOpen = true
    }

    function releaseHoverSuppression() {
        suppressHoverOpen = false
    }
}
