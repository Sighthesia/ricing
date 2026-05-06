import QtQuick
import "SuperIslandWindowHintWidthResolver.js" as WidthResolver

// SuperIsland width-chain geometry keeps the pure derived width and debug values together.
QtObject {
    id: root

    // Host-injected state: the SuperIsland host root that owns the exported width contract.
    required property QtObject host

    // Live collapsed width mirrors the width resolver's current pill measurement.
    readonly property real collapsedWidthLive: WidthResolver.collapsedWidthLive(host)

    // Idle collapsed width includes the host padding around the idle label measurement.
    readonly property real idleCollapsedWidthLive:
        ((host._idleMeasureLoader && host._idleMeasureLoader.item)
            ? host._idleMeasureLoader.item.implicitWidth
            : 0) + host._padH * 2

    // The main hint measurement is the widest measured main branch used by the width chain.
    readonly property real barExpandedMainHintWidthMeasured:
        WidthResolver.barExpandedMainHintWidthMeasured(host)

    // The bar-expanded main hint width resolves from the shared width helper.
    readonly property real barExpandedMainHintWidth:
        WidthResolver.barExpandedMainHintWidth(host)

    // The detached hint width resolves from the shared width helper.
    readonly property real barExpandedDetachedHintWidth:
        WidthResolver.barExpandedDetachedHintWidth(host)

    // Detached hint width is the current fallback width for non-bar-expanded hint sessions.
    readonly property real detachedHintWidth: WidthResolver.detachedHintWidth(host)

    // Bar-expanded title clamping stays derived from the shared width resolver and the latched return state.
    readonly property bool barExpandedTitleWidthClamped:
        host._barExpandedTitleRevealLatched
        && !host._barExpandedTailRectReleased
        && WidthResolver.barExpandedTitleWidthClamped(host)

    // Title reveal progress follows the exit reveal or the latched hint reveal progress.
    readonly property real barExpandedTitleRevealProgress:
        host._phase === "hint-exit"
            ? host._attachedVerticalRevealProgress
            : (host._barExpandedTitleRevealLatched ? 1 : host._attachedRevealProgress)

    // Title reveal width progress tracks the footprint width against the entry width.
    readonly property real barExpandedTitleRevealWidthProgress:
        host._barExpandedMainHintWidth > host._barExpandedEntryBaseWidth
            ? Math.max(
                0,
                Math.min(
                    1,
                    (host._barExpandedHostFootprintWidth - host._barExpandedEntryBaseWidth)
                        / (host._barExpandedMainHintWidth - host._barExpandedEntryBaseWidth)
                )
            )
            : 1

    // The collapsed width uses the shared resolver and stays separate from the live measurement.
    readonly property real collapsedWidth: WidthResolver.collapsedWidth(host)

    // The expanded width uses the shared resolver and stays separate from the live measurement.
    readonly property real expandedWidth: WidthResolver.expandedWidth(host)

    // Exit and overlay cleanup can temporarily borrow the attached collapse base width.
    readonly property bool useAttachedCollapseBaseWidth:
        host._attachedCollapseAnimating
        || host._phase === "hint-exit"
        || host._overlayClosing
        || (host._barExpandedHintActive && !host._barExpandedTitleRevealLatched)
}
