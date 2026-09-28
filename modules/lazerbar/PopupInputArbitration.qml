pragma Singleton
import QtQuick

// Shared read-only view of which rival surface is entitled to claim input at a
// given screen pixel.
//
// This exists because the tray submenu kept losing the pointer with healthy
// local state: the region covered the point, hit-testing reached the band, and
// the tray logic was correct — yet a leave arrived anyway. Diagnosing that
// needs one question answered per sample: "who is allowed to own this pixel?",
// asked of every surface that could compete, not just the one suspected.
//
// Note the layer layout this was built against:
//   afloat-popup        Top      (the bar popup)
//   afloat-notifications Top     (mapped after TopBar, so above the popup)
//   afloat-bar          Overlay  (ABOVE the Top layer entirely)
//   afloat-launcher     Top      (full screen, masked)
// A client cannot order two surfaces within one layer, and Overlay outranks
// Top, so afloat-bar is the surface that can take input from the popup without
// any cooperation from us.
QtObject {
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
