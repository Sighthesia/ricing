import QtQuick
import "../../services" as Services

// Hover-driven bridge between a bar widget and the shared popup host.
// A short open delay avoids drive-by popups; closing goes through the
// service's grace window so the pointer can travel into the popup surface.
Item {
    id: root

    // Popup kind registered in BarPopupService ("tray", "volume", ...).
    property string kind: ""
    // Kind-specific payload, e.g. a tray item for its DBus menu.
    property var payload: null
    // Delay before hover opens the popup so quick passes stay quiet.
    property int openDelayMs: 130

    anchors.fill: parent

    HoverHandler {
        id: popupHover

        enabled: root.kind !== "" && !Services.BarPopupService.suppressHoverOpen
        onHoveredChanged: {
            if (hovered) {
                Services.BarPopupService.cancelClose()
                openDelay.restart()
            } else {
                openDelay.stop()
                Services.BarPopupService.requestClose()
            }
        }
    }

    Timer {
        id: openDelay

        // Menu-bar convention: the first open waits out the delay, but a
        // popup that is already open retargets instantly while sweeping.
        interval: Services.BarPopupService.visible ? 0 : Math.max(0, root.openDelayMs)
        onTriggered: {
            if (!popupHover.hovered)
                return
            // Window-local X of this widget's leading edge. The host joins
            // its settings-style drawer to this edge rather than centering a
            // floating card around the widget.
            var anchorX = root.mapToItem(null, 0, 0).x
            Services.BarPopupService.open(root.kind, anchorX, root.payload)
        }
    }
}
