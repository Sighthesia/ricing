import QtQuick
import Quickshell
import qs.config
import qs.services

// Overlay session geometry keeps overlay modes, screen fallbacks, and measured body sizing together.
QtObject {
    id: root

    // Host-injected state: the SuperIsland host root that owns overlay loaders and exported contracts.
    required property QtObject host

    // Host-injected state: detached panel origin used to derive available body height.
    required property real overlayDetachedOffset

    // Whether the overlay fills the entire screen (break-reminder or session-control).
    readonly property bool fullScreenOverlayMode:
        IslandOverlayService.mode === "break-reminder"
        || IslandOverlayService.mode === "session-control"

    // Whether the overlay is in session-control full-screen mode specifically.
    readonly property bool fullScreenSessionOverlayMode:
        IslandOverlayService.mode === "session-control"

    // Whether the overlay is in control-center mode.
    readonly property bool controlCenterOverlayMode:
        IslandOverlayService.mode === "control-center"

    // Primary screen reference, falling back to null when no screens are available.
    readonly property var primaryScreen:
        Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // Effective screen width with fallback chain: primary → Screen → bar content.
    readonly property real screenWidth:
        (root.primaryScreen && root.primaryScreen.width ? root.primaryScreen.width : 0)
            || Screen.width
            || BarLayoutService.barContentWidth

    // Effective screen height with fallback chain: primary → Screen → 0.
    readonly property real screenHeight:
        (root.primaryScreen && root.primaryScreen.height ? root.primaryScreen.height : 0)
            || Screen.height
            || 0

    // Maximum body height available for the overlay, clamped by screen size and detached offset.
    readonly property real overlayAvailableBodyHeight:
        root.screenHeight > 0
            ? Math.max(root.host._pillH, root.screenHeight - root.overlayDetachedOffset)
            : Math.round(900 * Theme.uiScale)

    // Fallback body height for the control-center overlay page.
    readonly property real controlCenterFallbackBodyHeight: ThemeSuperIsland.superIslandControlCenterBodyHeight

    // Control-center body height prefers the live measurement loader but safely falls back to the deck host.
    readonly property real controlCenterMeasuredBodyHeight: Math.max(
        (root.host._overlayDeckMeasureLoader && root.host._overlayDeckMeasureLoader.item)
            ? root.host._overlayDeckMeasureLoader.item.implicitHeight
            : 0,
        (root.host._overlayDeckHost && root.host._overlayDeckHost.implicitHeight > 0)
            ? root.host._overlayDeckHost.implicitHeight
            : 0
    )

    // Overlay body height resolves the active mode before the host applies animation behavior.
    readonly property real overlayBodyHeight:
        root.fullScreenOverlayMode
            ? root.overlayAvailableBodyHeight
            : (root.controlCenterOverlayMode
                ? Math.min(
                    root.overlayAvailableBodyHeight,
                    root.controlCenterMeasuredBodyHeight > 0
                        ? root.controlCenterMeasuredBodyHeight
                        : root.controlCenterFallbackBodyHeight
                )
                : root.controlCenterFallbackBodyHeight)
}
