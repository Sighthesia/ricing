import QtQuick
import qs.config
import qs.services

// SuperIsland attached panel geometry keeps detached-session sizing and surface state together.
QtObject {
    id: root

    // Host-injected state: the SuperIsland host root that owns the motion orchestration.
    required property QtObject host

    // Detached hint activity stays scoped to full window-hint sessions and collapse cleanup.
    readonly property bool detachedHintActive:
        root.host._isFullHintEventType(root.host._attachedHintEvent.type)
        && (root.host._hintPhase || root.host._attachedCollapseAnimating)

    // Attached hint visibility stays aligned with detached hint activity for current host behavior.
    readonly property bool attachedHintVisible: root.detachedHintActive

    // Attached panel activity includes both overlay sessions and detached hint sessions.
    readonly property bool attachedPanelActive:
        root.host._overlaySessionActive || root.attachedHintVisible

    // Overlay closing stays delegated to the overlay service state while a session is active.
    readonly property bool overlayClosing:
        root.host._overlaySessionActive && IslandOverlayService.state === "closing"

    // Attached panel expanded state follows the current overlay or hint presentation mode.
    readonly property bool attachedPanelExpanded:
        root.host._overlaySessionActive
            ? (root.host._overlayExpandedActive || root.overlayClosing)
            : (root.host._hintPhase || root.host._attachedCollapseAnimating)

    // Live bar-expanded hint sizing only applies during the active hint phase before collapse cleanup.
    readonly property bool barExpandedHintLiveSizing:
        root.host._barExpandedHintActive && root.host._phase === "hint" && !root.host._attachedCollapseAnimating

    // Pill top margin drops to zero while the bar-expanded title host is attached to the lower panel.
    readonly property real pillBaseTopMargin:
        root.host._barExpandedHintActive && root.host._phase === "hint" ? 0 : root.host._padV

    // The attached panel width follows overlay width or the current detached hint width contract.
    readonly property real attachedPanelWidth:
        root.host._overlaySessionActive
            ? root.host._overlayExpandedWidth
            : (root.host._barExpandedHintActive
                ? Math.max(root.host._barExpandedMainHintWidth, root.host._barExpandedDetachedHintWidth)
                : root.host._detachedHintWidth)

    // Live detached hint height switches to the bar-expanded detached measure when needed.
    readonly property real liveDetachedHintSessionHeight:
        root.host._barExpandedHintActive ? root.barExpandedDetachedHintHeight : root.detachedHintHeight

    // Hint session height latches the largest valid detached height during collapse cleanup.
    readonly property real attachedHintSessionHeight:
        root.host._latchedDetachedHintSessionHeight > 0
            ? Math.max(root.host._latchedDetachedHintSessionHeight, root.liveDetachedHintSessionHeight)
            : root.liveDetachedHintSessionHeight

    // Attached panel height follows overlay body height or the latched detached hint session height.
    readonly property real attachedPanelHeight:
        root.host._overlaySessionActive
            ? root.host._overlayBodyHeight
            : (root.barExpandedHintLiveSizing ? root.liveDetachedHintSessionHeight : root.attachedHintSessionHeight)

    // Attached panel body width clamps the lower detached panel to the current visible upper host width when needed.
    readonly property real attachedPanelBodyWidth:
        root.host._overlaySessionActive
            ? root.host._attachedPanelVisibleWidth
            : (root.host._barExpandedHintActive
                ? Math.min(
                    root.host._barExpandedDetachedHintWidth,
                    root.host._pillTransitionControl
                        ? root.host._pillTransitionControl.animatedWidth
                        : root.host._barExpandedDetachedHintWidth
                )
                : root.host._attachedPanelVisibleWidth)

    // Detached hint reservation height keeps the reveal contract large enough for the active lower body.
    readonly property real detachedHintReservedHeight:
        Math.max(
            root.transientExpandedHeight,
            root.attachedHintSessionHeight,
            root.fullHintExpandedPillHeight + 2
        )

    // Detached hint height follows the measured detached card height with a safe fallback.
    readonly property real detachedHintHeight:
        Math.max(
            root.transientExpandedHeight,
            ((root.host._detachedHintMeasureLoader && root.host._detachedHintMeasureLoader.item)
                ? root.host._detachedHintMeasureLoader.item.implicitHeight
                : root.fullHintExpandedPillHeight) + 2
        )

    // Bar-expanded detached hint height uses the dedicated detached presentation measure.
    readonly property real barExpandedDetachedHintHeight:
        Math.max(
            root.transientExpandedHeight,
            ((root.host._detachedHintDetachedMeasureLoader && root.host._detachedHintDetachedMeasureLoader.item)
                ? root.host._detachedHintDetachedMeasureLoader.item.implicitHeight
                : root.fullHintExpandedPillHeight) + 2
        )

    // Attached panel opacity stays fully visible during hint sessions and follows overlay expansion otherwise.
    readonly property real attachedPanelOpacity:
        root.host._overlaySessionActive
            ? ((root.host._overlayExpandedActive || root.overlayClosing) ? 1 : 0)
            : (root.attachedHintVisible ? 1 : 0)

    // Attached panel scale only relaxes slightly while overlay sessions are not fully expanded yet.
    readonly property real attachedPanelScale:
        root.host._overlaySessionActive
            ? ((root.host._overlayExpandedActive || root.overlayClosing) ? 1 : 0.985)
            : 1

    // Attached content scale keeps non-overlay hint content aligned with the outer shell scale.
    readonly property real attachedContentScale:
        root.host._overlaySessionActive ? 1 : root.attachedPanelScale

    // Attached surface scale combines pulse scaling with the content/session scale.
    readonly property real attachedSurfaceScale:
        root.host._pulseScale * root.attachedContentScale

    // Shared clock scale follows the same surface scale while preserving the flash-lane shrink.
    readonly property real barExpandedSharedClockScale:
        root.attachedContentScale * root.host._flashScale

    // Shared clock opacity follows the attached panel opacity while preserving the flash-lane fade.
    readonly property real barExpandedSharedClockOpacity:
        root.attachedPanelOpacity * root.host._flashScale

    // Attached pulse opacity blends shared pulse state with the detached hint pulse when active.
    readonly property real attachedPulseOpacity:
        root.attachedPanelActive
            ? Math.max(
                root.host._sharedBackgroundPulseOpacity,
                root.host._barExpandedHintActive && root.host._resolverAttachedContentDeck
                    ? root.host._resolverAttachedContentDeck.hintPulseOpacity
                    : 0
            )
            : 0

    // The transient expanded height covers the stacked pill and flash row presentation.
    readonly property real transientExpandedHeight:
        root.host._pillH + root.host._flashGap + root.host._flashRowH

    // Collapsed pill height stays equal to the live host pill height.
    readonly property real collapsedPillHeight: root.host._pillH

    // Pill expansion state remains owned by the original phase machine and bar-expanded hint gate.
    readonly property bool pillExpanded:
        (root.host._phase === "enter" || root.host._phase === "hold")
        || (root.host._barExpandedHintActive && root.host._phase === "hint")

    // Full window-hint expanded height keeps all stage rows and padding in one derived total.
    readonly property real fullHintExpandedPillHeight:
        root.host._pillH
        + root.host._windowHintSideHeight * 2
        + root.host._windowHintPrimaryHeight
        + root.host._windowHintWorkspaceColumnGap * 2
        + root.host._windowHintRowGap
        + root.host._windowHintTitleHeight
        + Theme.barWidget.contentPaddingV * 2
        + root.host._windowHintStagePadV * 2

    // Expanded pill height switches to full bar height for the attached bar-expanded title lane.
    readonly property real expandedPillHeight:
        root.host._barExpandedHintActive
            ? Theme.barHeight
            : root.transientExpandedHeight
}
