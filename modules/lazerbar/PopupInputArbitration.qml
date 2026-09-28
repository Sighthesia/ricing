pragma Singleton
import QtQuick

// One-bit arbitration between the bar popup and the notification host.
//
// Both are layer-shell surfaces in the same layer, and the client cannot order
// two surfaces within one layer: the compositor decides, and decides it once, at
// map time. NotificationHost is declared after TopBar in shell.qml, so it maps
// later and therefore permanently sits ABOVE the popup. Whenever a notification
// card is on screen its input region (right edge, under the bar) overlaps the
// popup's rectangle, niri hands the pointer to the notification surface, and the
// popup receives a leave with the pointer still visibly over it — no highlight,
// no click, menu gone. Reproduced on the desktop: the tray submenu died at
// screen (1366.9, 165.5) with the notification region spanning x 1278..1638.
//
// This is the same one-owner-per-pixel rule the screen bezel already follows:
// the surface that owns a region paints it, and no other surface claims input
// over it. So while a bar popup owns the pointer, the notification host stands
// down. Stacking is not the lever here — the compositor owns that.
QtObject {
    // True while any bar popup is open or completing its exit reveal. Set by
    // the popup host; read by the notification host's input mask.
    property bool popupOwnsPointer: false

    // The notification stack's claimed input rect, published by its own owner
    // because that surface — not the popup — knows where its cards are. Kept in
    // screen coordinates so any surface can test a point against it without
    // walking a scene graph it does not own. Read by diagnostics only.
    property real notifX: -1
    property real notifY: -1
    property real notifWidth: 0
    property real notifHeight: 0

    function claimInputRegion(x, y, width, height) {
        notifX = x
        notifY = y
        notifWidth = width
        notifHeight = height
    }

    function releaseInputRegion() {
        notifX = -1
        notifY = -1
        notifWidth = 0
        notifHeight = 0
    }

    function coversPoint(px, py) {
        if (notifHeight <= 0 || px < 0)
            return false
        return px >= notifX && px <= notifX + notifWidth
            && py >= notifY && py <= notifY + notifHeight
    }
}
