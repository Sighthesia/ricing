import QtQuick
import Quickshell
import qs.config
import qs.services

// Overlay geometry cluster: screen info, mode flags, shell shape, and positioning constants.
QtObject {
    id: root

    // Host-injected state: whether the bar-expanded window hint is active.
    required property bool barExpandedHintActive

    // Host-injected state: current pill height from the host widget.
    required property real pillHeight

    // Host-injected state: current bar-expanded title clamp state.
    required property bool barExpandedTitleWidthClamped

    // Host-injected state: current pill background width from the visible surface.
    required property real pillBackgroundWidth

    // Host-injected state: detached hint width used by the seam arc clamp.
    required property real barExpandedDetachedHintWidth

    // Host-injected state: current hint phase used by the tail-release gate.
    required property string phase

    // Host-injected state: whether the attached panel is in closing cleanup.
    required property bool overlayClosing

    // Host-injected state: current reveal progress for the attached panel.
    required property real attachedRevealProgress

    // Host-injected state: current visible attached panel height.
    required property real attachedPanelVisibleHeight

    // Host-injected state: window-hint side height used by the tail-release gate.
    required property real windowHintSideHeight

    // Host-injected state: pulse opacity blended into the detached panel surface.
    required property real attachedPulseOpacity

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
        (primaryScreen && primaryScreen.width ? primaryScreen.width : 0)
            || Screen.width
            || BarLayoutService.barContentWidth

    // Effective screen height with fallback chain: primary → Screen → 0.
    readonly property real screenHeight:
        (primaryScreen && primaryScreen.height ? primaryScreen.height : 0)
            || Screen.height
            || 0

    // Whether the detached panel uses a rectangular top seam instead of a pill shape.
    readonly property bool barExpandedRectangularMode: root.barExpandedHintActive

    // Top-corner radius used when the bar host switches to rectangular mode.
    readonly property real barExpandedTopRadius:
        Math.max(
            Theme.cornerRadius * ThemeSuperIsland.overlayTopRadiusCornerFactor,
            Math.round(Theme.barWidget.pillHeight * ThemeSuperIsland.overlayTopRadiusPillFactor)
        )

    // Lower-corner radius for the detached panel in bar-expanded mode.
    readonly property real barExpandedDetachedRadius:
        Math.max(
            Theme.cornerRadius * ThemeSuperIsland.overlayDetachedRadiusCornerFactor,
            Math.round(Theme.barWidget.pillHeight * ThemeSuperIsland.overlayDetachedRadiusPillFactor)
        )

    // Seam arc radius mirrors the detached panel corner radius.
    readonly property real barExpandedSeamArcRadius: root.barExpandedDetachedRadius

    // The tail rectangle can release once exit cleanup has mostly completed.
    readonly property bool barExpandedTailRectReleased:
        root.barExpandedHintActive
        && (root.phase === "hint-exit" || root.overlayClosing)
        && (root.attachedRevealProgress <= 0.16
            || root.attachedPanelVisibleHeight
                <= Math.max(root.windowHintSideHeight, root.overlayAttachmentOverlap + 2))

    // Decorative seam arcs shrink away once the title clamp has fully taken over.
    readonly property real barExpandedSeamArcProgress: {
        if (root.barExpandedTitleWidthClamped)
            return 0

        var widthDelta = Math.max(0, root.pillBackgroundWidth - root.barExpandedDetachedHintWidth)
        var fullArcWidthDelta = Math.max(1, root.barExpandedDetachedRadius * 2)
        return Math.max(0, Math.min(1, widthDelta / fullArcWidthDelta))
    }

    // Effective outer shell corner radius depending on rectangular vs. pill mode.
    readonly property real overlayShellRadius:
        root.barExpandedRectangularMode
            ? root.barExpandedDetachedRadius
            : Math.max(Theme.cornerRadius, Theme.screenCornerRadius)

    // Inward corner radius matches the shell radius.
    readonly property real overlayInwardCornerRadius: root.overlayShellRadius

    // Depth of the inward corner notch that frames the attached panel seam.
    readonly property real overlayInwardCornerDepth:
        Math.max(
            ThemeSuperIsland.overlayInwardCornerDepthBase,
            root.overlayInwardCornerRadius
                + (root.overlayInwardCornerRadius - ThemeSuperIsland.overlayInwardCornerDepthBase)
                    * ThemeSuperIsland.overlayInwardCornerDepthTension
        )

    // Vertical lift applied when the attached panel first reveals.
    readonly property real overlayRevealLift:
        ThemeSuperIsland.overlayRevealLift

    // Pixel overlap between the pill host and the attached panel seam.
    readonly property real overlayAttachmentOverlap: ThemeSuperIsland.overlayAttachmentOverlap

    // Bridge outset is reserved for future bridging; currently unused.
    readonly property real overlayBridgeOutset: 0

    // Vertical offset from the bar top to the detached panel origin.
    readonly property real overlayDetachedOffset:
        root.fullScreenSessionOverlayMode
            ? Theme.barHeight
            : (root.barExpandedHintActive
                ? Theme.barHeight + root.overlayAttachmentOverlap
                : Math.max(Theme.barHeight, root.pillHeight + root.overlayInwardCornerDepth))

    // Alias used by downstream panel hosts to position the detached panel.
    readonly property real overlayDetachedY: root.overlayDetachedOffset

    // Maximum body height available for the overlay, clamped by screen size and detached offset.
    readonly property real overlayAvailableBodyHeight:
        root.screenHeight > 0
            ? Math.max(root.pillHeight, root.screenHeight - root.overlayDetachedOffset)
            : Math.round(900 * Theme.uiScale)

    // Fallback body height for the control-center overlay page.
    readonly property real controlCenterFallbackBodyHeight: ThemeSuperIsland.superIslandControlCenterBodyHeight

    // Shell fill opacity drops for full-screen overlays to show the desktop behind.
    readonly property real attachedShellFillOpacity:
        root.fullScreenOverlayMode ? 0.78 : 1

    // Detached panel surface tint blends the shared pulse into the shell fill.
    readonly property color barExpandedPanelSurfaceColor: Qt.rgba(
        Colors.surface.r * (1 - root.attachedPulseOpacity) + Colors.highlight.r * root.attachedPulseOpacity,
        Colors.surface.g * (1 - root.attachedPulseOpacity) + Colors.highlight.g * root.attachedPulseOpacity,
        Colors.surface.b * (1 - root.attachedPulseOpacity) + Colors.highlight.b * root.attachedPulseOpacity,
        root.attachedShellFillOpacity
    )
}
