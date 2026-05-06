import QtQuick
import qs.config

// SuperIsland track geometry keeps the return target and track centering math together.
QtObject {
    id: root

    // Host-injected state: the SuperIsland host root that owns the visible track values.
    required property QtObject host

    // Host-injected state: the latched return target center, if return mode has already locked it.
    required property real barExpandedSharedClockTargetCenterYLatched

    // Track centering keeps the lane offsets in one place so all related rows use the same math.
    function trackCenterY(item, zoneHeight, event, includeOpticalOffset) {
        const itemHeight = item ? item.implicitHeight : zoneHeight
        const opticalOffset = includeOpticalOffset && event && event.type === "idle"
            ? root.host._idleOpticalOffset
            : 0
        return (zoneHeight - itemHeight) / 2 + opticalOffset
    }

    // Loader access stays guarded so the helper can evaluate before every child is ready.
    function _mainLoaderItem() {
        return root.host && root.host._mainLoader ? root.host._mainLoader.item : null
    }

    // Strip loader access stays guarded so the helper can evaluate before every child is ready.
    function _stripLoaderItem() {
        return root.host && root.host._stripLoader ? root.host._stripLoader.item : null
    }

    // Idle loader access stays guarded so the helper can evaluate before every child is ready.
    function _idleLoaderItem() {
        return root.host && root.host._idleMeasureLoader ? root.host._idleMeasureLoader.item : null
    }

    // Main track enter Y keeps the exit/return launch point derived from the live pill height.
    readonly property real mainTrackEnterY:
        -Math.max(root.host._pillH, root._mainLoaderItem() ? root._mainLoaderItem().implicitHeight : root.host._pillH)

    // Main track zone expands to the full bar height while the bar-expanded hint is active.
    readonly property real mainTrackZoneHeight:
        root.host._barExpandedHintActive ? Theme.barHeight : root.host._pillH

    // Main track center follows the live card height and the current track zone.
    readonly property real mainTrackCenterY:
        root.trackCenterY(root._mainLoaderItem(), root.mainTrackZoneHeight, root.host._mainDisplayEvent, true)

    // Flash track center follows the shared strip card height.
    readonly property real flashTrackCenterY:
        root.trackCenterY(root._stripLoaderItem(), root.host._pillH, root.host._flashSourceEvent, false)

    // Flash row base anchors the transient stack below the pill.
    readonly property real flashRowBaseY: root.host._pillH + root.host._flashGap

    // Flash lane center sits in the middle of the transient row.
    readonly property real flashLaneCenterY: root.flashRowBaseY + root.host._flashRowH / 2

    // Flash strip Y combines the row base with the strip card centering offset.
    readonly property real flashStripY:
        root.flashRowBaseY
        + root.trackCenterY(root._stripLoaderItem(), root.host._flashRowH, root.host._flashSourceEvent, false)

    // Main flash track Y combines the row base with the main card centering offset.
    readonly property real mainFlashTrackY:
        root.flashRowBaseY
        + root.trackCenterY(root._mainLoaderItem(), root.host._flashRowH, root.host._mainDisplayEvent, true)

    // Hint track Y lifts the main track by the configured hint offset.
    readonly property real hintTrackY: root.mainTrackCenterY - root.host._hintLift

    // Return track center falls back to the strip track unless bar-expanded return mode is active.
    readonly property real returnTrackCenterY:
        root.host._barExpandedHintActive || root.host._phase === "hint-exit"
            ? root.barExpandedSharedClockTargetCenterY
            : root.trackCenterY(root._stripLoaderItem(), root.host._pillH, root.host._flashSourceEvent, false)

    // Return width live uses the current source event and the live idle width when available.
    readonly property real returnWidthLive:
        root.host._flashSourceEvent.type === "idle"
            ? root.host._idleCollapsedWidthLive
            : ((root._stripLoaderItem() ? root._stripLoaderItem().implicitWidth : 0) + root.host._padH * 2)

    // Return width can latch to the attached collapse base width while the return path is in flight.
    readonly property real returnWidth:
        root.host._useAttachedCollapseBaseWidth && root.host._attachedCollapseBaseWidth > 0
            ? root.host._attachedCollapseBaseWidth
            : root.returnWidthLive

    // Transition collapsed width uses the return width only when exit mode owns the geometry.
    readonly property real transitionCollapsedWidth:
        root.host._phase === "exit"
            ? root.returnWidth
            : (root.host._barExpandedHintActive && root.host._phase === "hint-exit"
                ? root.host._idleCollapsedWidthLive
                : root.host._collapsedWidth)

    // Shared clock landing Y anchors the returned clock at the idle lane's visual center.
    readonly property real barExpandedSharedClockLandingY:
        root.host._padV + root.trackCenterY(root._idleLoaderItem(), root.host._pillH, null, true)

    // Shared clock start center is based on the landing Y plus the shared clock height.
    readonly property real barExpandedSharedClockStartCenterY:
        root.barExpandedSharedClockLandingY + root.host._barExpandedSharedClockHeight / 2

    // Shared clock start Y is the same as the landing Y for the top-aligned clock item.
    readonly property real barExpandedSharedClockStartY: root.barExpandedSharedClockLandingY

    // Shared clock target center resolves to the latched return target or the live seam-backed target.
    function resolveBarExpandedSharedClockTargetCenterY() {
        if (root.barExpandedSharedClockTargetCenterYLatched > 0)
            return root.barExpandedSharedClockTargetCenterYLatched

        const overlayPanelHost = root.host && root.host._overlayPanelHost ? root.host._overlayPanelHost : null
        const attachedContentDeck = root.host ? root.host._attachedContentDeck : null
        const hintCardLoaderItem = attachedContentDeck ? attachedContentDeck.hintCardLoaderItem : null

        return (overlayPanelHost ? overlayPanelHost.y + 1 : 1)
            + ((hintCardLoaderItem && hintCardLoaderItem.relocatedClockCenterY !== undefined)
                ? hintCardLoaderItem.relocatedClockCenterY
                : Math.max(root.host._pillH / 2, root.host._attachedPanelVisibleHeight - root.host._pillH / 2))
    }

    // Return target helper stays exposed so the host can latch the same resolved center.
    readonly property real barExpandedSharedClockTargetCenterYResolved:
        root.resolveBarExpandedSharedClockTargetCenterY()

    // Shared clock target center resolves through the helper so the host can reuse the same rule.
    readonly property real barExpandedSharedClockTargetCenterY: root.barExpandedSharedClockTargetCenterYResolved

    // Shared clock target Y is derived from the resolved target center and the clock height.
    readonly property real barExpandedSharedClockTargetY:
        root.barExpandedSharedClockTargetCenterY - root.host._barExpandedSharedClockHeight / 2

    // Shared clock base Y interpolates between the landing and target centers as the reveal progresses.
    readonly property real barExpandedSharedClockBaseY:
        root.barExpandedSharedClockStartCenterY
        + (root.barExpandedSharedClockTargetCenterY - root.barExpandedSharedClockStartCenterY)
            * root.host._attachedVerticalRevealProgress
        - root.host._barExpandedSharedClockHeight / 2

    // Shared clock Y adds the pill throw offset to the base interpolation.
    readonly property real barExpandedSharedClockY:
        root.barExpandedSharedClockBaseY + root.host._pillThrowOffsetY
}
