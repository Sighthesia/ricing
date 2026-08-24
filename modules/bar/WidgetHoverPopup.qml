import QtQuick
import "../../../services" as Services

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

        interval: Math.max(0, root.openDelayMs)
        onTriggered: {
            if (!popupHover.hovered)
                return
            // Window-local X of this widget's center; the host adds the
            // floating margin since both windows share horizontal insets.
            var anchorX = root.mapToItem(null, root.width / 2, 0).x
            Services.BarPopupService.open(root.kind, anchorX, root.payload)
        }
    }
}
