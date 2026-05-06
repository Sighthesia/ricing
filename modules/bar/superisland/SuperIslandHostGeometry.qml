import QtQuick
import qs.config
import "SuperIslandWindowHintWidthResolver.js" as WidthResolver

// SuperIsland host geometry keeps reservation and reveal measurements together.
QtObject {
    id: root

    // Host-injected state: the SuperIsland host root that owns the exported contract.
    required property QtObject host

    // The bar reservation follows only the top host footprint; the detached lower panel is visual-only.
    readonly property real barExpandedHostFootprintWidth: WidthResolver.barExpandedHostFootprintWidth(host)

    // Exported reservation width stays host-owned while the helper computes the shared value.
    readonly property real layoutReservationWidth: root.barExpandedHostFootprintWidth

    // Exported measurement width follows the same host footprint as reservation width.
    readonly property real layoutMeasurementWidth: root.barExpandedHostFootprintWidth

    // Context-menu hit height stays aligned with the bar host footprint.
    readonly property real layoutContextMenuHeight: Theme.barHeight

    // Reveal height includes the bar host and the currently visible attached panel surface.
    readonly property real layoutRevealHeight: Math.max(
        Theme.barHeight,
        ((host._overlayPanelHost ? host._overlayPanelHost.y : 0) + host._attachedPanelVisibleHeight),
        ((host._pillClip ? host._pillClip.y : 0) + (host._pillClip ? host._pillClip.height : Theme.barHeight))
    )
}
