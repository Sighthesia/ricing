import Quickshell
import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import ".." as BarComponents
import ".." as BarPanels
import "../superisland" as IslandCards
import "../superisland/SuperIslandWindowHintWidthResolver.js" as WidthResolver

// Visual SuperIsland host that delegates transition state orchestration to SuperIslandStateMachine.
Item {
    id: root

    property bool liveInstance: false
    property string debugInstanceLabel: liveInstance ? "live" : "preview"
    readonly property bool _debugLogging:
        (Quickshell.env("DYMICSHELL_SUPERISLAND_DEBUG") || "").trim() === "1"
    readonly property bool _debugWidthLogging:
        (Quickshell.env("DYMICSHELL_SUPERISLAND_WIDTH_DEBUG") || "").trim() === "1"
    property string _lastWindowHintReturnDebugSignature: ""
    property alias _windowHintReturnSession: _viewState._windowHintReturnSession
    property alias _windowHintReturnStep: _viewState._windowHintReturnStep

    onLiveInstanceChanged: {
        _stateMachine.syncOverlayExtensionReservation()
    }

    IslandCards.SuperIslandViewState {
        id: _viewState
    }

    // Card component registry owns all card Component definitions and selection logic.
    IslandCards.SuperIslandCardComponentRegistry {
        id: _cardRegistry

        pillHeight: root._pillH
        flashRowHeight: root._flashRowH
        currentTime: root.currentTime
        hasPendingEvents: SuperIslandService.hasPendingEvents
        overlayExpandedWidth: root._overlayExpandedWidth
        phase: root._phase
        barExpandedTitleRevealProgress: root._barExpandedTitleRevealProgress
        barExpandedTitleRevealWidthProgress: root._barExpandedTitleRevealWidthProgress
        attachedVerticalRevealProgress: root._attachedVerticalRevealProgress
        barExpandedSharedClockVisible: root._barExpandedSharedClockVisible
        barExpandedMainCardVisible: root._barExpandedMainCardVisible
        contentPaddingV: Theme.barWidget.contentPaddingV
    }

    // Overlay geometry helper owns screen info, mode flags, and shell shape properties.
    IslandCards.SuperIslandOverlayGeometry {
        id: _overlayGeometry
        barExpandedHintActive: root._barExpandedHintActive
        pillHeight: root._pillH
    }

    property alias currentTime: _viewState.currentTime

    readonly property int _padV: Theme.iconPadding
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _pillH: Theme.barWidget.pillHeight
    readonly property int _flashGap: Theme.barWidget.stackGap
    readonly property int _flashRowH: Theme.barWidget.pillHeight
    readonly property int _hintPulsePad: Theme.barWidget.focusPulsePadding
    readonly property int _hintLift: Theme.barWidget.contentPaddingV
    readonly property int _replaceOffset: Math.max(6, Theme.barWidget.contentPaddingV * 3)
    readonly property int _replaceDelay: Math.max(50, Math.round(Theme.anim.highlightDuration / 2))
    readonly property real _flashScale: 0.85

    property alias _phase: _viewState._phase
    property alias _mainDisplayEvent: _viewState._mainDisplayEvent
    property alias _flashSourceEvent: _viewState._flashSourceEvent
    property alias _replaceOutgoingEvent: _viewState._replaceOutgoingEvent
    property alias _replaceIncomingEvent: _viewState._replaceIncomingEvent
    property alias _lastActiveEvent: _viewState._lastActiveEvent
    property alias _mainTrackY: _viewState._mainTrackY
    property alias _mainTrackScale: _viewState._mainTrackScale
    property alias _mainTrackOpacity: _viewState._mainTrackOpacity
    property alias _flashTrackY: _viewState._flashTrackY
    property alias _flashTrackScale: _viewState._flashTrackScale
    property alias _flashTrackOpacity: _viewState._flashTrackOpacity

    readonly property var _notificationEntryMeta: ({
        outgoingBaseline: ({
            targetY: root._flashStripY,
            deltaY: root._flashStripY - root._flashTrackCenterY,
            targetCenterY: root._flashLaneCenterY,
            scale: root._flashScale,
            opacity: 0.6,
            durationToken: "moveDuration",
            easingToken: "moveType"
        }),
        incomingTransient: ({
            targetY: root._mainTrackCenterY,
            deltaY: root._mainTrackCenterY - root._mainTrackEnterY,
            targetCenterY: root._mainTrackCenterY
                + ((_mainLoader.item ? _mainLoader.item.implicitHeight : root._pillH) / 2),
            scale: 1,
            opacity: 1,
            durationToken: "moveDuration",
            easingToken: "moveType"
        })
    })

    readonly property var _windowHintEntryMeta: ({
        mainRole: ({
            targetY: root._mainFlashTrackY,
            deltaY: root._mainFlashTrackY - root._mainTrackCenterY,
            targetCenterY: root._flashLaneCenterY,
            scale: root._notificationEntryMeta.outgoingBaseline.scale,
            opacity: root._notificationEntryMeta.outgoingBaseline.opacity,
            durationToken: root._notificationEntryMeta.outgoingBaseline.durationToken,
            easingToken: root._notificationEntryMeta.outgoingBaseline.easingToken
        }),
        mainFlashLaneTargetY: root._mainFlashTrackY,
        flashLaneTargetY: Theme.barWidget.contentPaddingV,
        flashLaneCenterY: root._flashLaneCenterY,
        flashRole: ({
            targetY: Theme.barWidget.contentPaddingV,
            deltaY: root._notificationEntryMeta.incomingTransient.deltaY,
            targetCenterY: root._flashLaneCenterY,
            scale: root._notificationEntryMeta.incomingTransient.scale,
            opacity: root._notificationEntryMeta.incomingTransient.opacity,
            durationToken: root._notificationEntryMeta.incomingTransient.durationToken,
            easingToken: root._notificationEntryMeta.incomingTransient.easingToken
        })
    })

    readonly property var _baselineEvent: _cardRegistry.displayEvent(SuperIslandService.mainState)
    readonly property string transitionMode:
        root._phase === "exit" ? "exit-track"
        : (root._phase === "idle" ? "single-track" : "dual-track")
    readonly property bool flashTrackVisible: root._phase !== "idle" && !root._detachedHintActive
    readonly property bool _transientPhase: root._phase !== "idle"
    property alias _overlaySessionActive: _viewState._overlaySessionActive
    property alias _overlayExpandedActive: _viewState._overlayExpandedActive
    readonly property real pillTopPadding: root._padV

    readonly property real _mainTrackZoneHeight:
        root._barExpandedHintActive ? Theme.barHeight : root._pillH
    readonly property real _mainTrackCenterY:
        root._trackCenterY(_mainLoader.item, root._mainTrackZoneHeight, root._mainDisplayEvent, true)
    readonly property real _flashTrackCenterY:
        root._trackCenterY(_stripLoader.item, root._pillH, root._flashSourceEvent, false)
    readonly property real _flashRowBaseY: root._pillH + root._flashGap
    readonly property real _flashLaneCenterY: root._flashRowBaseY + root._flashRowH / 2
    readonly property real _flashStripY:
        root._flashRowBaseY
        + root._trackCenterY(_stripLoader.item, root._flashRowH, root._flashSourceEvent, false)
    readonly property real _mainFlashTrackY:
        root._flashRowBaseY
        + root._trackCenterY(_mainLoader.item, root._flashRowH, root._mainDisplayEvent, true)

    readonly property int _windowHintStagePadV: ThemeSuperIsland.windowHintStagePadV
    readonly property int _windowHintRowGap: ThemeSuperIsland.windowHintRowGap
    readonly property int _windowHintWorkspaceColumnGap: ThemeSuperIsland.windowHintWorkspaceColumnGap
    readonly property int _windowHintSideHeight: ThemeSuperIsland.windowHintWorkspaceSideHeight
    readonly property int _windowHintPrimaryHeight: ThemeSuperIsland.windowHintWorkspacePrimaryHeight
    readonly property int _windowHintTitleHeight: ThemeSuperIsland.windowHintTitleCapsuleHeight

    readonly property real _hintTrackY: root._mainTrackCenterY - root._hintLift
    readonly property real _hintDividerY: root._pillH + Math.max(0, (root._flashGap - 1) / 2)
    readonly property real _hintBackgroundY: root._flashRowBaseY
    readonly property real _hintBackgroundHeight: root._flashRowH
    readonly property real _hintBackgroundPulseOpacity:
        root._hintPhase && !root._isHintEventType(root._flashSourceEvent.type)
            ? root._sharedBackgroundPulseOpacity
            : 0
    readonly property real _returnTrackCenterY:
        root._barExpandedHintActive || root._phase === "hint-exit"
            ? root._barExpandedSharedClockTargetCenterY
            : root._trackCenterY(_stripLoader.item, root._pillH, root._flashSourceEvent, false)

    // Overlay mode flags and screen geometry delegated to the geometry helper.
    readonly property alias _fullScreenOverlayMode: _overlayGeometry.fullScreenOverlayMode
    readonly property alias _fullScreenSessionOverlayMode: _overlayGeometry.fullScreenSessionOverlayMode
    readonly property alias _controlCenterOverlayMode: _overlayGeometry.controlCenterOverlayMode
    readonly property alias _primaryScreen: _overlayGeometry.primaryScreen
    readonly property alias _screenWidth: _overlayGeometry.screenWidth
    readonly property alias _screenHeight: _overlayGeometry.screenHeight
    readonly property alias _overlayAvailableBodyHeight: _overlayGeometry.overlayAvailableBodyHeight
    readonly property alias _controlCenterFallbackBodyHeight: _overlayGeometry.controlCenterFallbackBodyHeight
    readonly property real _controlCenterMeasuredBodyHeight: Math.max(
        _overlayDeckMeasureLoader.item ? _overlayDeckMeasureLoader.item.implicitHeight : 0,
        _overlayDeckHost.implicitHeight > 0 ? _overlayDeckHost.implicitHeight : 0
    )
    property real _overlayBodyHeight:
        root._fullScreenOverlayMode
            ? root._overlayAvailableBodyHeight
            : (root._controlCenterOverlayMode
                ? Math.min(
                    root._overlayAvailableBodyHeight,
                    root._controlCenterMeasuredBodyHeight > 0
                        ? root._controlCenterMeasuredBodyHeight
                        : root._controlCenterFallbackBodyHeight
                )
                : root._controlCenterFallbackBodyHeight)
    Behavior on _overlayBodyHeight {
        enabled: !root._fullScreenOverlayMode

        NumberAnimation {
            duration: Math.max(1, SettingsService.effectiveAnimation.staggerExitDuration)
            easing.type: Theme.anim.moveType
        }
    }
    // Overlay positioning and shape geometry delegated to the geometry helper.
    readonly property alias _overlayDetachedOffset: _overlayGeometry.overlayDetachedOffset
    readonly property alias _overlayDetachedY: _overlayGeometry.overlayDetachedY
    readonly property alias _overlayRevealLift: _overlayGeometry.overlayRevealLift
    readonly property alias _overlayAttachmentOverlap: _overlayGeometry.overlayAttachmentOverlap
    readonly property alias _barExpandedRectangularMode: _overlayGeometry.barExpandedRectangularMode
    readonly property alias _barExpandedTopRadius: _overlayGeometry.barExpandedTopRadius
    readonly property alias _barExpandedDetachedRadius: _overlayGeometry.barExpandedDetachedRadius
    readonly property alias _barExpandedSeamArcRadius: _overlayGeometry.barExpandedSeamArcRadius
    readonly property bool _barExpandedTailRectReleased:
        root._barExpandedHintActive
        && (root._phase === "hint-exit" || root._overlayClosing)
        && (root._attachedRevealProgress <= 0.16
            || root._attachedPanelVisibleHeight <= Math.max(root._windowHintSideHeight, root._overlayAttachmentOverlap + 2))
    readonly property real _barExpandedSeamArcProgress: {
        if (root._barExpandedTitleWidthClamped)
            return 0

        const widthDelta = Math.max(0, _pillBg.width - root._barExpandedDetachedHintWidth)
        const fullArcWidthDelta = Math.max(1, root._barExpandedSeamArcRadius * 2)
        return Math.max(0, Math.min(1, widthDelta / fullArcWidthDelta))
    }
    // Shell shape properties delegated to the geometry helper.
    readonly property alias _overlayShellRadius: _overlayGeometry.overlayShellRadius
    readonly property real _overlayPillBackgroundWidth: _pillBg.width
    readonly property alias _overlayBridgeOutset: _overlayGeometry.overlayBridgeOutset
    readonly property alias _overlayInwardCornerRadius: _overlayGeometry.overlayInwardCornerRadius
    readonly property alias _overlayInwardCornerDepth: _overlayGeometry.overlayInwardCornerDepth

    readonly property real _attachedRevealSeedHeight: 0
    readonly property real _attachedRevealSeedWidth: WidthResolver.attachedRevealSeedWidth(root)
    readonly property real _attachedCollapseBaseWidthCandidate: WidthResolver.attachedCollapseBaseWidthCandidate(root)

    readonly property real _pillThrowLift:
        Math.max(6, Math.round(root._pillH * 0.2))
    readonly property real _pillThrowDrop:
        Math.max(10, Math.round(root._pillH * 0.32))
    readonly property int _pillThrowLeadDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.5))
    readonly property int _pillThrowDropDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.7))

    readonly property bool _detachedHintActive:
        root._isFullHintEventType(root._attachedHintEvent.type)
        && (root._hintPhase || root._attachedCollapseAnimating)
    readonly property bool _attachedHintVisible:
        root._isFullHintEventType(root._attachedHintEvent.type)
        && (root._hintPhase || root._attachedCollapseAnimating)
    readonly property bool _attachedPanelActive:
        root._overlaySessionActive || root._attachedHintVisible
    readonly property bool _overlayClosing:
        root._overlaySessionActive && IslandOverlayService.state === "closing"
    readonly property bool _attachedPanelExpanded:
        root._overlaySessionActive
            ? (root._overlayExpandedActive || root._overlayClosing)
            : (root._hintPhase || root._attachedCollapseAnimating)
    readonly property bool _barExpandedHintLiveSizing:
        root._barExpandedHintActive && root._phase === "hint" && !root._attachedCollapseAnimating
    readonly property real _pillBaseTopMargin:
        root._barExpandedHintActive && root._phase === "hint" ? 0 : root._padV
    readonly property real _attachedPanelWidth:
        root._overlaySessionActive
            ? root._overlayExpandedWidth
            : (root._barExpandedHintActive
                ? Math.max(root._barExpandedMainHintWidth, root._barExpandedDetachedHintWidth)
                : root._detachedHintWidth)
    readonly property real _liveDetachedHintSessionHeight:
        root._barExpandedHintActive ? root._barExpandedDetachedHintHeight : root._detachedHintHeight
    readonly property real _attachedHintSessionHeight:
        root._latchedDetachedHintSessionHeight > 0
            ? Math.max(root._latchedDetachedHintSessionHeight, root._liveDetachedHintSessionHeight)
            : root._liveDetachedHintSessionHeight
    readonly property real _attachedPanelHeight:
        root._overlaySessionActive
            ? root._overlayBodyHeight
            : (root._barExpandedHintLiveSizing ? root._liveDetachedHintSessionHeight : root._attachedHintSessionHeight)
    readonly property real _attachedPanelBodyWidth:
        root._overlaySessionActive
            ? root._attachedPanelVisibleWidth
            : (root._barExpandedHintActive
                ? Math.min(root._barExpandedDetachedHintWidth, _pillTransitionControl.animatedWidth)
                : root._attachedPanelVisibleWidth)
    readonly property real _detachedHintReservedHeight:
        Math.max(
            root._transientExpandedHeight,
            root._attachedHintSessionHeight,
            root._fullHintExpandedPillHeight + 2
        )
    readonly property real _detachedHintWidth: WidthResolver.detachedHintWidth(root)
    readonly property real _barExpandedMainHintWidthMeasured: WidthResolver.barExpandedMainHintWidthMeasured(root)
    readonly property real _barExpandedMainHintWidth: WidthResolver.barExpandedMainHintWidth(root)
    readonly property real _barExpandedDetachedHintWidth: WidthResolver.barExpandedDetachedHintWidth(root)
    readonly property bool _barExpandedTitleWidthClamped:
        root._barExpandedTitleRevealLatched
        && !root._barExpandedTailRectReleased
        && WidthResolver.barExpandedTitleWidthClamped(root)
    readonly property bool _barExpandedHintActive:
        root._detachedHintActive && root._attachedHintEvent.presentation === "bar-expanded"
    // Bar reservation must follow only the top host footprint; the detached lower panel is visual-only.
    readonly property real _barExpandedHostFootprintWidth: WidthResolver.barExpandedHostFootprintWidth(root)
    readonly property real layoutReservationWidth: root._barExpandedHostFootprintWidth
    readonly property real layoutMeasurementWidth: root._barExpandedHostFootprintWidth
    readonly property real layoutRevealHeight: Math.max(
        Theme.barHeight,
        ((_overlayPanelHost ? _overlayPanelHost.y : 0) + root._attachedPanelVisibleHeight),
        ((_pillClip ? _pillClip.y : 0) + (_pillClip ? _pillClip.height : Theme.barHeight))
    )
    readonly property real _detachedHintHeight:
        Math.max(
            root._transientExpandedHeight,
            (_detachedHintMeasureLoader.item
                ? _detachedHintMeasureLoader.item.implicitHeight
                : root._fullHintExpandedPillHeight) + 2
        )
    readonly property real _barExpandedDetachedHintHeight:
        Math.max(
            root._transientExpandedHeight,
            (_detachedHintDetachedMeasureLoader.item
                ? _detachedHintDetachedMeasureLoader.item.implicitHeight
                : root._fullHintExpandedPillHeight) + 2
        )
    readonly property real _attachedPanelOpacity:
        root._overlaySessionActive
            ? ((root._overlayExpandedActive || root._overlayClosing) ? 1 : 0)
            : (root._attachedHintVisible ? 1 : 0)
    readonly property real _attachedPanelScale:
        root._overlaySessionActive
            ? ((root._overlayExpandedActive || root._overlayClosing) ? 1 : 0.985)
            : 1
    readonly property real _attachedContentScale:
        root._overlaySessionActive ? 1 : root._attachedPanelScale
    readonly property real _attachedSurfaceScale:
        root._pulseScale * root._attachedContentScale
    readonly property real _barExpandedSharedClockScale:
        root._attachedContentScale * root._flashScale
    readonly property real _barExpandedSharedClockOpacity:
        root._attachedPanelOpacity * root._flashScale
    readonly property real _attachedPulseOpacity:
        root._attachedPanelActive
            ? Math.max(
                root._sharedBackgroundPulseOpacity,
                root._barExpandedHintActive ? _attachedContentDeck.hintPulseOpacity : 0
            )
            : 0
    readonly property color _barExpandedPanelSurfaceColor: Qt.rgba(
        Colors.surface.r * (1 - root._attachedPulseOpacity) + Colors.highlight.r * root._attachedPulseOpacity,
        Colors.surface.g * (1 - root._attachedPulseOpacity) + Colors.highlight.g * root._attachedPulseOpacity,
        Colors.surface.b * (1 - root._attachedPulseOpacity) + Colors.highlight.b * root._attachedPulseOpacity,
        root._attachedShellFillOpacity
    )

    readonly property real _transientExpandedHeight:
        root._pillH + root._flashGap + root._flashRowH
    readonly property real _collapsedPillHeight: root._pillH
    readonly property bool _pillExpanded:
        (root._phase === "enter" || root._phase === "hold")
        || (root._barExpandedHintActive && root._phase === "hint")

    readonly property real _overlayExpandedWidth: {
        if (root._fullScreenOverlayMode)
            return Math.max(root._collapsedWidth, root._screenWidth)

        const availableWidth = Math.max(
            760,
            BarLayoutService.barContentWidth - Math.max(24, Theme.barPadding * 2)
        )
        return Math.max(root._collapsedWidth, Math.min(Math.round(980 * Theme.uiScale), availableWidth))
    }
    // Shell fill opacity delegated to the geometry helper.
    readonly property alias _attachedShellFillOpacity: _overlayGeometry.attachedShellFillOpacity

    readonly property real _fullHintExpandedPillHeight:
        root._pillH
        + root._windowHintSideHeight * 2
        + root._windowHintPrimaryHeight
        + root._windowHintWorkspaceColumnGap * 2
        + root._windowHintRowGap
        + root._windowHintTitleHeight
        + Theme.barWidget.contentPaddingV * 2
        + root._windowHintStagePadV * 2

    readonly property real _expandedPillHeight:
        root._barExpandedHintActive
            ? Theme.barHeight
            : root._transientExpandedHeight
    readonly property real _verticalRevealSurfaceHeight: _verticalReveal.surfaceHeight
    readonly property real _verticalRevealClipHeight: _verticalReveal.clipHeight

    property real _barExpandedEntryBaseWidth: 0
    property real _barExpandedExitBaseWidth: 0
    property bool _barExpandedTitleRevealLatched: false
    readonly property real _collapsedWidthLive: WidthResolver.collapsedWidthLive(root)
    readonly property real _idleCollapsedWidthLive:
        (_idleMeasureLoader.item ? _idleMeasureLoader.item.implicitWidth : 0) + root._padH * 2
    readonly property real _barExpandedTitleRevealProgress:
        root._phase === "hint-exit"
            ? root._attachedVerticalRevealProgress
            : (root._barExpandedTitleRevealLatched ? 1 : root._attachedRevealProgress)
    readonly property real _barExpandedTitleRevealWidthProgress:
        root._barExpandedMainWidth > root._barExpandedEntryBaseWidth
            ? Math.max(
                0,
                Math.min(
                    1,
                    (root._barExpandedHostFootprintWidth - root._barExpandedEntryBaseWidth)
                        / (root._barExpandedMainWidth - root._barExpandedEntryBaseWidth)
                )
            )
            : 1
    readonly property bool _useAttachedCollapseBaseWidth:
        root._attachedCollapseAnimating
        || root._phase === "hint-exit"
        || root._overlayClosing
        || (root._barExpandedHintActive && !root._barExpandedTitleRevealLatched)
    readonly property real _collapsedWidth: WidthResolver.collapsedWidth(root)
    readonly property real _expandedWidth: WidthResolver.expandedWidth(root)

    readonly property real _mainTrackEnterY:
        -Math.max(root._pillH, _mainLoader.item ? _mainLoader.item.implicitHeight : root._pillH)
    readonly property real _returnWidthLive:
        root._flashSourceEvent.type === "idle"
            ? root._idleCollapsedWidthLive
            : ((_stripLoader.item ? _stripLoader.item.implicitWidth : 0) + root._padH * 2)
    readonly property real _returnWidth:
        root._useAttachedCollapseBaseWidth && root._attachedCollapseBaseWidth > 0
            ? root._attachedCollapseBaseWidth
            : root._returnWidthLive
    readonly property real _transitionCollapsedWidth:
        root._phase === "exit"
            ? root._returnWidth
            : (root._barExpandedHintActive && root._phase === "hint-exit"
                ? root._idleCollapsedWidthLive
                : root._collapsedWidth)
    readonly property real _idleOpticalOffset: 0
    readonly property bool _hintPhase: root._phase === "hint" || root._phase === "hint-exit"
    readonly property bool _listensToService: true
    readonly property real _transientAccentBaseOpacity: 0
    readonly property real _overlayReservedExtension:
        root._attachedPanelActive
            ? root._overlayDetachedOffset
                + (root._overlaySessionActive
                    ? root._attachedPanelHeight
                    : root._detachedHintReservedHeight)
            : 0
    readonly property real _overlayShellY: _pillClip.y
    readonly property real _overlayShellHeight:
        Math.max(0, (_overlayPanelHost.y + root._attachedPanelVisibleHeight) - root._overlayShellY)
    readonly property real _attachedShellPillHeight:
        root._barExpandedHintActive ? Theme.barHeight : root._pillH
    readonly property bool _attachedShellVisible:
        root._attachedPanelActive && !root._barExpandedHintActive

    property alias _replaceOutgoingY: _viewState._replaceOutgoingY
    property alias _replaceOutgoingOpacity: _viewState._replaceOutgoingOpacity
    property alias _replaceOutgoingTargetY: _viewState._replaceOutgoingTargetY
    property alias _replaceIncomingY: _viewState._replaceIncomingY
    property alias _replaceIncomingOpacity: _viewState._replaceIncomingOpacity
    property alias _replaceOutgoingVisible: _viewState._replaceOutgoingVisible
    property alias _replaceIncomingVisible: _viewState._replaceIncomingVisible
    property alias _sharedBackgroundPulseOpacity: _viewState._sharedBackgroundPulseOpacity
    property alias _pulseScale: _viewState._pulseScale
    property alias _overlayPulsePending: _viewState._overlayPulsePending
    property alias _pulseOwner: _viewState._pulseOwner
    property alias _attachedPanelRevealWidth: _viewState._attachedPanelRevealWidth
    property alias _attachedPanelRevealHeight: _viewState._attachedPanelRevealHeight
    property alias _attachedContentOpacity: _viewState._attachedContentOpacity
    property alias _attachedCollapseAnimating: _viewState._attachedCollapseAnimating
    property alias _pillThrowOffsetY: _viewState._pillThrowOffsetY
    property alias _attachedRevealUseHandoffCurve: _viewState._attachedRevealUseHandoffCurve
    property alias _attachedCollapseBaseWidth: _viewState._attachedCollapseBaseWidth
    property alias _overlayHandoffHintEvent: _viewState._overlayHandoffHintEvent
    property alias _overlayHintHandoffActive: _viewState._overlayHintHandoffActive
    property alias _attachedHintEvent: _viewState._attachedHintEvent
    property real _latchedDetachedHintSessionHeight: 0
    property alias _pillTransition: _pillTransitionControl
    property alias _resolverPillTransitionControl: _pillTransitionControl
    property alias _resolverPillClip: _pillClip
    property alias _resolverMainLoader: _mainLoader
    property alias _resolverStripLoader: _stripLoader
    property alias _resolverDetachedHintMeasureLoader: _detachedHintMeasureLoader
    property alias _resolverBarExpandedMainMeasureLoader: _barExpandedMainMeasureLoader
    property alias _resolverDetachedHintDetachedMeasureLoader: _detachedHintDetachedMeasureLoader

    readonly property real _attachedPanelVisibleWidth:
        root._attachedPanelActive
            ? Math.max(
                root._attachedRevealSeedWidth,
                Math.min(root._attachedPanelRevealWidth, root._attachedPanelWidth)
            )
            : root._attachedRevealSeedWidth
    readonly property real _attachedPanelVisibleHeight:
        root._attachedPanelActive
            ? Math.max(0, Math.min(root._attachedPanelRevealHeight, root._attachedPanelHeight))
            : 0
    readonly property real _attachedWidthRevealProgress:
        root._attachedPanelWidth > root._attachedRevealSeedWidth
            ? Math.max(
                0,
                Math.min(
                    1,
                    (Math.min(root._attachedPanelRevealWidth, root._attachedPanelWidth) - root._attachedRevealSeedWidth)
                        / (root._attachedPanelWidth - root._attachedRevealSeedWidth)
                )
            )
            : 1
    readonly property real _attachedHeightRevealProgress:
        root._attachedPanelHeight > root._attachedRevealSeedHeight
            ? Math.max(
                0,
                Math.min(
                    1,
                    (root._attachedPanelVisibleHeight - root._attachedRevealSeedHeight)
                        / (root._attachedPanelHeight - root._attachedRevealSeedHeight)
                )
            )
            : 1
    readonly property real _attachedRevealProgress:
        root._attachedPanelActive
            ? Math.min(root._attachedWidthRevealProgress, root._attachedHeightRevealProgress)
            : 0
    readonly property real _attachedVerticalRevealProgress:
        root._barExpandedHintActive ? root._attachedHeightRevealProgress : root._attachedRevealProgress
    readonly property real _attachedRevealYOffset:
        (1 - root._attachedVerticalRevealProgress) * root._overlayRevealLift
    property bool _hintRevealSettled: false
    readonly property bool _barExpandedSharedClockVisible:
        root._barExpandedHintActive
        || (root._phase === "idle" && root._mainDisplayEvent && root._mainDisplayEvent.type === "idle"
            && root._lastActiveEvent && root._lastActiveEvent.presentation === "bar-expanded")
    readonly property bool _barExpandedMainCardVisible:
        root._barExpandedHintActive
        && !root._attachedCollapseTailHidden
        && root._attachedPanelVisibleHeight > Math.max(0, root._windowHintSideHeight / 2)
    readonly property bool _barExpandedWindowHintTailActive:
        root._barExpandedHintActive
        && root._mainDisplayEvent
        && root._mainDisplayEvent.type === "window-hint"
        && root._phase !== "hint"
        && !root._barExpandedMainCardVisible
    readonly property real _barExpandedSharedClockHeight: root._pillH
    readonly property real _pillAnimatedWidth: _pillTransitionControl.animatedWidth
    property var _barExpandedSharedClockEvent: root._baselineEvent
    readonly property real _barExpandedSharedClockLandingY:
        root._padV + root._trackCenterY(_idleMeasureLoader.item, root._pillH, null, true)
    readonly property real _barExpandedSharedClockStartCenterY:
        root._barExpandedSharedClockLandingY + root._barExpandedSharedClockHeight / 2
    readonly property real _barExpandedSharedClockStartY:
        root._barExpandedSharedClockLandingY
    readonly property real _barExpandedSharedClockTargetCenterY:
        root._resolveBarExpandedSharedClockTargetCenterY()
    property real _barExpandedSharedClockTargetCenterYLatched: 0
    readonly property real _barExpandedSharedClockTargetY:
        root._barExpandedSharedClockTargetCenterY - root._barExpandedSharedClockHeight / 2
    readonly property real _barExpandedSharedClockBaseY:
        root._barExpandedSharedClockStartCenterY
        + (root._barExpandedSharedClockTargetCenterY - root._barExpandedSharedClockStartCenterY)
            * root._attachedVerticalRevealProgress
        - root._barExpandedSharedClockHeight / 2
    readonly property real _barExpandedSharedClockY:
        root._barExpandedSharedClockBaseY + root._pillThrowOffsetY
    readonly property bool _showOverlayHandoffHint:
        root._overlayHintHandoffActive
        && root._overlaySessionActive
        && root._attachedRevealProgress < 0.78
    readonly property bool _attachedCollapseTailHidden:
        root._attachedPanelActive
        && (root._phase === "hint-exit" || root._overlayClosing)

implicitHeight: Theme.barHeight
implicitWidth: root._barExpandedHintActive
    ? Math.max(0, root.layoutMeasurementWidth)
    : Math.max(0, _pillTransitionControl.animatedWidth)
width: implicitWidth

    Component.onCompleted: _stateMachine.initialize()
    Component.onDestruction: _stateMachine.teardown()
    on_OverlayBodyHeightChanged: _stateMachine.syncOverlayExtensionReservation()
    on_OverlayDetachedOffsetChanged: _stateMachine.syncOverlayExtensionReservation()
    on_BarExpandedHintActiveChanged: {
        root._syncDetachedHintSessionHeight()

        if (root._barExpandedHintActive) {
            root._barExpandedSharedClockEvent = root._baselineEvent
            const baseWidth = Math.max(0, _pillTransitionControl.animatedWidth)
            root._barExpandedEntryBaseWidth = baseWidth
            root._barExpandedExitBaseWidth = baseWidth
            root._barExpandedTitleRevealLatched = false
            root._hintRevealSettled = false
            root._logWidthChain("barExpandedHintActive=true")
            return
        }

        root._barExpandedEntryBaseWidth = 0
        root._barExpandedExitBaseWidth = 0
        root._barExpandedTitleRevealLatched = false
        root._hintRevealSettled = false
        root._logWidthChain("barExpandedHintActive=false")
    }
    on_BarExpandedSharedClockVisibleChanged: {
        if (!root._barExpandedSharedClockVisible) {
            root._releaseBarExpandedSharedClockReturnTarget()
        }
    }
    on_HintRevealSettledChanged: {
        if (!root._barExpandedHintActive || !root._hintRevealSettled)
            return

        root._barExpandedEntryBaseWidth = 0
        root._barExpandedTitleRevealLatched = true
        root._logWidthChain("hintRevealSettled")
    }
    on_PhaseChanged: {
        if (root._phase === "hint-exit" && root._barExpandedHintActive) {
            root._latchBarExpandedSharedClockReturnTarget()
        }

        root._syncBarExpandedExitBaseWidth()
        root._logWidthChain("phaseChanged")
    }
    on_ExpandedWidthChanged: root._logWidthChain("expandedWidthChanged")
    on_CollapsedWidthChanged: root._logWidthChain("collapsedWidthChanged")
    on_AttachedPanelWidthChanged: root._retargetAttachedPanelWidthIfNeeded()
    on_AttachedPanelHeightChanged: {
        _stateMachine.syncOverlayExtensionReservation()
        root._retargetAttachedPanelHeightIfNeeded()
    }
    on_AttachedPanelVisibleHeightChanged: _stateMachine.syncOverlayExtensionReservation()
    on_AttachedPanelVisibleWidthChanged: root._syncBarExpandedExitBaseWidth()
    on_DetachedHintActiveChanged: root._syncDetachedHintSessionHeight()
    on_AttachedCollapseAnimatingChanged: root._syncDetachedHintSessionHeight()
    on_DetachedHintHeightChanged: root._syncDetachedHintSessionHeight()
    on_BarExpandedDetachedHintHeightChanged: root._syncDetachedHintSessionHeight()

    function _syncDetachedHintSessionHeight() {
        if (root._overlaySessionActive)
            return

        if (!root._detachedHintActive && !root._attachedCollapseAnimating) {
            root._latchedDetachedHintSessionHeight = 0
            return
        }

        if (root._detachedHintActive && !root._attachedCollapseAnimating) {
            root._latchedDetachedHintSessionHeight = root._liveDetachedHintSessionHeight
            return
        }

        root._latchedDetachedHintSessionHeight = Math.max(
            root._latchedDetachedHintSessionHeight,
            root._liveDetachedHintSessionHeight
        )
    }

    function _resolveBarExpandedSharedClockTargetCenterY() {
        if (root._barExpandedSharedClockTargetCenterYLatched > 0)
            return root._barExpandedSharedClockTargetCenterYLatched

        return (_overlayPanelHost ? _overlayPanelHost.y + 1 : 1)
            + ((_attachedContentDeck && _attachedContentDeck.hintCardLoaderItem
                    && _attachedContentDeck.hintCardLoaderItem.relocatedClockCenterY !== undefined)
                ? _attachedContentDeck.hintCardLoaderItem.relocatedClockCenterY
                : Math.max(root._pillH / 2, root._attachedPanelVisibleHeight - root._pillH / 2))
    }

    function _latchBarExpandedSharedClockReturnTarget() {
        root._barExpandedSharedClockTargetCenterYLatched = root._resolveBarExpandedSharedClockTargetCenterY()
        root._barExpandedSharedClockEvent = root._baselineEvent
    }

    function _releaseBarExpandedSharedClockReturnTarget() {
        root._barExpandedSharedClockTargetCenterYLatched = 0
        root._barExpandedSharedClockEvent = root._baselineEvent
    }

    function _syncBarExpandedExitBaseWidth() {
        if (!root._barExpandedHintActive || root._phase !== "hint-exit")
            return

        root._barExpandedExitBaseWidth = Math.max(
            root._barExpandedExitBaseWidth,
            _pillTransitionControl ? _pillTransitionControl.animatedWidth : 0,
            root._attachedPanelVisibleWidth,
            root._barExpandedDetachedHintWidth,
            root._idleCollapsedWidthLive
        )
    }

    function _retargetAttachedPanelWidthIfNeeded() {
        if (!root._attachedPanelActive || !root._attachedPanelExpanded || root._overlayClosing)
            return

        if (Math.abs(root._attachedPanelWidth - root._attachedPanelRevealWidth) <= 0.5)
            return

        if (root._detachedHintActive && !root._barExpandedHintActive && root._attachedPanelWidth > root._attachedPanelRevealWidth) {
            _attachedWidthRetargetAnim.stop()
            _viewState._attachedPanelRevealWidth = root._attachedPanelWidth
            return
        }

        _attachedWidthRetargetAnim.stop()
        _attachedWidthRetargetAnim.from = root._attachedPanelRevealWidth
        _attachedWidthRetargetAnim.to = root._attachedPanelWidth
        _attachedWidthRetargetAnim.start()
    }

    function _retargetAttachedPanelHeightIfNeeded() {
        if (!root._attachedPanelActive || !root._attachedPanelExpanded || root._overlayClosing)
            return

        if (Math.abs(root._attachedPanelHeight - root._attachedPanelRevealHeight) <= 0.5)
            return

        if (root._detachedHintActive && !root._attachedCollapseAnimating && !root._barExpandedHintActive) {
            _attachedHeightRetargetAnim.stop()

            if (root._attachedPanelHeight > root._attachedPanelRevealHeight)
                _viewState._attachedPanelRevealHeight = root._attachedPanelHeight

            return
        }

        if (root._barExpandedHintActive
                && !root._attachedCollapseAnimating
                && root._attachedContentOpacity >= 0.99) {
            _attachedHeightRetargetAnim.stop()
            _viewState._attachedPanelRevealHeight = root._attachedPanelHeight
            return
        }

        if (root._detachedHintActive && root._attachedPanelHeight > root._attachedPanelRevealHeight) {
            _attachedHeightRetargetAnim.stop()
            _viewState._attachedPanelRevealHeight = root._attachedPanelHeight
            return
        }

        _attachedHeightRetargetAnim.stop()
        _attachedHeightRetargetAnim.from = root._attachedPanelRevealHeight
        _attachedHeightRetargetAnim.to = root._attachedPanelHeight
        _attachedHeightRetargetAnim.start()
    }

    // Wrapper functions that delegate to the card registry for backward compatibility.
    function _idleSnapshot() {
        return _cardRegistry.idleSnapshot()
    }

    function _displayEvent(event) {
        return _cardRegistry.displayEvent(event)
    }

    function _cloneEvent(event) {
        return _cardRegistry.cloneEvent(event)
    }

    function _isHintEventType(eventType) {
        return eventType === "window-hint"
    }

    function _isFullHintEventType(eventType) {
        return eventType === "window-hint"
    }

    function _resolvedIconSource(iconName) {
        if (!iconName)
            return Quickshell.iconPath("dialog-information")
        if (iconName.indexOf("://") !== -1 || iconName.startsWith("/"))
            return iconName
        return Quickshell.iconPath(iconName, "dialog-information")
    }

    function _deferPillSnapToCollapsed() {
        Qt.callLater(function() {
            if (root._pillTransition && typeof root._pillTransition.snapToCollapsed === "function")
                root._pillTransition.snapToCollapsed()
        })
    }

    function _deferPillSnapToExpanded() {
        Qt.callLater(function() {
            if (root._pillTransition && typeof root._pillTransition.snapToExpanded === "function")
                root._pillTransition.snapToExpanded()
        })
    }

    function _preferredOverlayPage() {
        const configuredPage = SettingsService.data.superIsland
            ? SettingsService.data.superIsland.expandedDefaultPage
            : "launcher"

        if (configuredPage === "settings" || configuredPage === "control-center")
            return configuredPage

        if (configuredPage === "notifications")
            return "notifications"

        return "launcher"
    }

    function _trackCenterY(item, zoneHeight, event, includeOpticalOffset) {
        const itemHeight = item ? item.implicitHeight : zoneHeight
        const opticalOffset = includeOpticalOffset && event && event.type === "idle"
            ? root._idleOpticalOffset
            : 0
        return (zoneHeight - itemHeight) / 2 + opticalOffset
    }

    function _logWidthChain(context) {
        if (!root._debugWidthLogging)
            return

        console.log("[DymicShell:SuperIslandWidth]", JSON.stringify({
            label: root.debugInstanceLabel,
            context: context,
            phase: root._phase,
            presentation: root._attachedHintEvent && root._attachedHintEvent.presentation ? root._attachedHintEvent.presentation : "",
            barExpandedHintActive: root._barExpandedHintActive,
            layoutMeasurementWidth: Math.round(root.layoutMeasurementWidth || 0),
            layoutReservationWidth: Math.round(root.layoutReservationWidth || 0),
            hostFootprintWidth: Math.round(root._barExpandedHostFootprintWidth || 0),
            animatedWidth: Math.round((_pillTransitionControl && _pillTransitionControl.animatedWidth) || 0),
            collapsedWidthLive: Math.round(root._collapsedWidthLive || 0),
            collapsedWidth: Math.round(root._collapsedWidth || 0),
            expandedWidth: Math.round(root._expandedWidth || 0),
            detachedHintWidth: Math.round(root._detachedHintWidth || 0),
            barExpandedMainHintWidthMeasured: Math.round(root._barExpandedMainHintWidthMeasured || 0),
            barExpandedMainHintWidth: Math.round(root._barExpandedMainHintWidth || 0),
            barExpandedDetachedHintWidth: Math.round(root._barExpandedDetachedHintWidth || 0),
            mainLoaderImplicitWidth: Math.round((_mainLoader.item && _mainLoader.item.implicitWidth) || 0),
            stripLoaderImplicitWidth: Math.round((_stripLoader.item && _stripLoader.item.implicitWidth) || 0),
            barExpandedMainMeasureImplicitWidth: Math.round((_barExpandedMainMeasureLoader.item && _barExpandedMainMeasureLoader.item.implicitWidth) || 0),
            detachedMeasureImplicitWidth: Math.round((_detachedHintMeasureLoader.item && _detachedHintMeasureLoader.item.implicitWidth) || 0),
            detachedDetachedMeasureImplicitWidth: Math.round((_detachedHintDetachedMeasureLoader.item && _detachedHintDetachedMeasureLoader.item.implicitWidth) || 0)
        }))
    }

    function _beginWindowHintReturnSession(reason) {
        if (!root._debugLogging)
            return

        root._windowHintReturnSession += 1
        root._windowHintReturnStep = 0
        root._lastWindowHintReturnDebugSignature = ""

        console.log("[DymicShell:SuperIslandReturn]", JSON.stringify({
            label: root.debugInstanceLabel,
            context: "windowHintReturnSession:start",
            reason: reason || "",
            returnSession: root._windowHintReturnSession,
            returnStep: 0,
            phase: root._phase,
            attachedHintType: root._attachedHintEvent && root._attachedHintEvent.type ? root._attachedHintEvent.type : "",
            attachedHintPresentation: root._attachedHintEvent && root._attachedHintEvent.presentation ? root._attachedHintEvent.presentation : "",
            mainType: root._mainDisplayEvent && root._mainDisplayEvent.type ? root._mainDisplayEvent.type : "",
            flashType: root._flashSourceEvent && root._flashSourceEvent.type ? root._flashSourceEvent.type : "",
            source: "session-start"
        }))
    }

    function _logWindowHintReturn(context, note, source) {
        if (!root._debugLogging)
            return

        const hasReturnSession = root._windowHintReturnSession > 0
        const returnStep = hasReturnSession ? root._windowHintReturnStep + 1 : 0
        const snapshot = {
            label: root.debugInstanceLabel,
            context: context,
            note: note || "",
            reason: note || "",
            source: source || "",
            returnSession: hasReturnSession ? root._windowHintReturnSession : 0,
            returnStep: returnStep,
            phase: root._phase,
            attachedHintType: root._attachedHintEvent && root._attachedHintEvent.type ? root._attachedHintEvent.type : "",
            attachedHintPresentation: root._attachedHintEvent && root._attachedHintEvent.presentation ? root._attachedHintEvent.presentation : "",
            mainType: root._mainDisplayEvent && root._mainDisplayEvent.type ? root._mainDisplayEvent.type : "",
            flashType: root._flashSourceEvent && root._flashSourceEvent.type ? root._flashSourceEvent.type : "",
            barExpandedHintActive: root._barExpandedHintActive,
            barExpandedSharedClockVisible: root._barExpandedSharedClockVisible,
            barExpandedSharedClockTargetCenterY: Math.round(root._barExpandedSharedClockTargetCenterY || 0),
            barExpandedSharedClockTargetCenterYLatched: Math.round(root._barExpandedSharedClockTargetCenterYLatched || 0),
            barExpandedSharedClockY: Math.round(root._barExpandedSharedClockY || 0),
            mainTrackY: Math.round(root._mainTrackY || 0),
            mainTrackScale: Math.round(root._mainTrackScale * 1000) / 1000,
            mainTrackOpacity: Math.round(root._mainTrackOpacity * 1000) / 1000,
            flashTrackY: Math.round(root._flashTrackY || 0),
            flashTrackScale: Math.round(root._flashTrackScale * 1000) / 1000,
            flashTrackOpacity: Math.round(root._flashTrackOpacity * 1000) / 1000,
            attachedPanelRevealWidth: Math.round(root._attachedPanelRevealWidth || 0),
            attachedPanelRevealHeight: Math.round(root._attachedPanelRevealHeight || 0),
            attachedContentOpacity: Math.round(root._attachedContentOpacity * 1000) / 1000,
            attachedCollapseAnimating: root._attachedCollapseAnimating,
            implicitWidth: Math.round(root.implicitWidth || 0),
            layoutMeasurementWidth: Math.round(root.layoutMeasurementWidth || 0),
            pillAnimatedWidth: Math.round(root._pillAnimatedWidth || 0)
        }

        const signature = JSON.stringify({
            context: snapshot.context,
            returnSession: snapshot.returnSession,
            phase: snapshot.phase,
            attachedHintType: snapshot.attachedHintType,
            attachedHintPresentation: snapshot.attachedHintPresentation,
            mainType: snapshot.mainType,
            flashType: snapshot.flashType,
            barExpandedHintActive: snapshot.barExpandedHintActive,
            barExpandedSharedClockVisible: snapshot.barExpandedSharedClockVisible,
            barExpandedSharedClockTargetCenterY: snapshot.barExpandedSharedClockTargetCenterY,
            barExpandedSharedClockTargetCenterYLatched: snapshot.barExpandedSharedClockTargetCenterYLatched,
            barExpandedSharedClockY: snapshot.barExpandedSharedClockY,
            mainTrackY: snapshot.mainTrackY,
            mainTrackScale: snapshot.mainTrackScale,
            mainTrackOpacity: snapshot.mainTrackOpacity,
            flashTrackY: snapshot.flashTrackY,
            flashTrackScale: snapshot.flashTrackScale,
            flashTrackOpacity: snapshot.flashTrackOpacity,
            attachedPanelRevealWidth: snapshot.attachedPanelRevealWidth,
            attachedPanelRevealHeight: snapshot.attachedPanelRevealHeight,
            attachedContentOpacity: snapshot.attachedContentOpacity,
            attachedCollapseAnimating: snapshot.attachedCollapseAnimating,
            implicitWidth: snapshot.implicitWidth,
            layoutMeasurementWidth: snapshot.layoutMeasurementWidth,
            pillAnimatedWidth: snapshot.pillAnimatedWidth
        })
        if (signature === root._lastWindowHintReturnDebugSignature)
            return

        if (hasReturnSession)
            root._windowHintReturnStep = returnStep

        root._lastWindowHintReturnDebugSignature = signature
        console.log("[DymicShell:SuperIslandReturn]", signature)
    }

    Timer {
        id: timeTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    NumberAnimation {
        id: _attachedWidthRetargetAnim
        target: _viewState
        property: "_attachedPanelRevealWidth"
        duration: Theme.anim.springDuration
        easing.type: Theme.anim.springType
        easing.overshoot: Theme.anim.springOvershoot
    }

    NumberAnimation {
        id: _attachedHeightRetargetAnim
        target: _viewState
        property: "_attachedPanelRevealHeight"
        duration: Theme.anim.springDuration
        easing.type: Theme.anim.springType
        easing.overshoot: Theme.anim.springOvershoot
    }

    IslandCards.SuperIslandStateMachine {
        id: _stateMachine
        host: root
        state: _viewState
    }

    BarComponents.BarTransientRevealHost {
        id: _verticalReveal

        collapsedHeight: root._collapsedPillHeight
        expandedHeight: root._expandedPillHeight
        expanded: root._pillExpanded
        extensionOwnerKey: root.liveInstance ? "super-island" : ""
        animateSurface: false
        sharedTransition: _pillTransitionControl
    }

    BarComponents.BarExpandTransition {
        id: _pillTransitionControl

        collapsedWidth: root._transitionCollapsedWidth
        expandedWidth: root._expandedWidth
        collapsedHeight: root._collapsedPillHeight
        expandedHeight: root._expandedPillHeight
        expanded: root._pillExpanded
        animateWidth: true
        animateHeight: !root._barExpandedHintActive
        freezeExpandedRetargeting: false
    }

    Item {
        id: _pillClip
        anchors.top: parent.top
        anchors.topMargin: root._pillBaseTopMargin + root._pillThrowOffsetY
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        implicitWidth: _pillTransitionControl.animatedWidth
        implicitHeight: root._verticalRevealClipHeight
        width: _pillTransitionControl.animatedWidth
        height: root._verticalRevealClipHeight
        scale: root._pulseScale
        transformOrigin: Item.Center

        // Main bar host becomes a slimmer rounded rectangle during bar-expanded window hint.
        Rectangle {
            id: _pillBg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root._verticalRevealSurfaceHeight
            radius: root._barExpandedRectangularMode ? root._barExpandedTopRadius : root._pillH / 2
            topLeftRadius: root._barExpandedRectangularMode ? root._barExpandedTopRadius : radius
            topRightRadius: root._barExpandedRectangularMode ? root._barExpandedTopRadius : radius
            bottomLeftRadius: root._barExpandedTitleWidthClamped ? 0 : radius
            bottomRightRadius: root._barExpandedTitleWidthClamped ? 0 : radius
            color: Colors.surface
            border.color: Colors.border
            border.width: root._attachedPanelActive ? 0 : 1
        }

        Rectangle {
            anchors.left: _pillBg.left
            anchors.right: _pillBg.right
            anchors.bottom: _pillBg.bottom
            height: _pillBg.radius
            color: Colors.surface
            visible: root._barExpandedTitleWidthClamped
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (root._phase === "hint" || root._phase === "hint-exit")
                ? root._hintDividerY
                : (root._pillH + Math.max(0, (root._flashGap - height) / 2))
            width: Math.max(0, _pillBg.width - root._padH * 2)
            height: 1
            radius: height / 2
            color: Colors.border
            opacity: root._phase !== "idle"
                && !root._barExpandedHintActive
                && root._flashSourceEvent.type !== "window-hint"
                    ? 0.35
                    : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        // Highlight surface mirrors the host seam shape during bar-expanded clamping.
        Rectangle {
            anchors.fill: _pillBg
            radius: _pillBg.radius
            topLeftRadius: _pillBg.topLeftRadius
            topRightRadius: _pillBg.topRightRadius
            bottomLeftRadius: _pillBg.bottomLeftRadius
            bottomRightRadius: _pillBg.bottomRightRadius
            color: Colors.highlight
            opacity: (root._transientPhase || root._overlaySessionActive)
                ? Math.min(1, root._transientAccentBaseOpacity + root._sharedBackgroundPulseOpacity)
                : 0
        }

        Rectangle {
            anchors.left: _pillBg.left
            anchors.right: _pillBg.right
            anchors.bottom: _pillBg.bottom
            height: _pillBg.radius
            color: Colors.highlight
            opacity: (root._transientPhase || root._overlaySessionActive)
                ? Math.min(1, root._transientAccentBaseOpacity + root._sharedBackgroundPulseOpacity)
                : 0
            visible: root._barExpandedTitleWidthClamped && opacity > 0
        }

        Rectangle {
            x: 0
            y: root._hintBackgroundY
            width: _pillBg.width
            height: root._hintBackgroundHeight
            radius: height / 2
            color: Colors.highlight
            opacity: root._hintBackgroundPulseOpacity
            visible: root.flashTrackVisible && root._flashSourceEvent.type !== "window-hint"
        }

        Loader {
            id: _replaceLoader
            property var eventData: root._replaceOutgoingEvent
            property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
            readonly property bool _windowHintReplaceBlocked:
                eventData && eventData.type === "window-hint" && root._barExpandedWindowHintTailActive
            anchors.horizontalCenter: parent.horizontalCenter
            active: root._replaceOutgoingVisible && !_windowHintReplaceBlocked
            y: root._replaceOutgoingY
            opacity: _windowHintReplaceBlocked ? 0 : root._replaceOutgoingOpacity
            sourceComponent: _cardRegistry.componentForEvent(eventData, false)
        }

        Loader {
            id: _replaceIncomingLoader
            property var eventData: root._replaceIncomingEvent
            property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
            readonly property bool _windowHintReplaceBlocked:
                eventData && eventData.type === "window-hint" && root._barExpandedWindowHintTailActive
            anchors.horizontalCenter: parent.horizontalCenter
            active: root._replaceIncomingVisible && !_windowHintReplaceBlocked
            y: root._replaceIncomingY
            opacity: _windowHintReplaceBlocked ? 0 : root._replaceIncomingOpacity
            sourceComponent: _cardRegistry.componentForEvent(eventData, false)
        }

        Loader {
            id: _mainLoader
            property var eventData: root._mainDisplayEvent
            property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
            readonly property bool _windowHintMainCardActive:
                eventData && eventData.type === "window-hint" && root._barExpandedHintActive
            anchors.horizontalCenter: parent.horizontalCenter
            y: root._mainTrackY
            scale: root._mainTrackScale
            opacity: (root._replaceOutgoingVisible || root._replaceIncomingVisible
                    || root._barExpandedWindowHintTailActive
                    || (_windowHintMainCardActive && !root._barExpandedMainCardVisible))
                ? 0
                : root._mainTrackOpacity
            sourceComponent: _cardRegistry.componentForEvent(eventData, false)
    }

    Loader {
        id: _stripLoader
        property var eventData: root._flashSourceEvent
        property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
        anchors.horizontalCenter: parent.horizontalCenter
        active: root.flashTrackVisible && !root._isFullHintEventType(eventData.type)
        y: root._flashTrackY
        opacity: root._flashTrackOpacity
        scale: root._flashTrackScale
        height: root._isFullHintEventType(eventData.type)
            ? root._verticalRevealSurfaceHeight
            : root._flashRowH
        clip: !root._isFullHintEventType(eventData.type)
        sourceComponent: _cardRegistry.componentForEvent(eventData, true)
    }
    }

    BarPanels.AttachedExpansionShell {
        id: _overlayShellHost

        anchorItem: _pillClip
        active: root._attachedShellVisible
        collapseTailHidden: root._attachedCollapseTailHidden
        visibleWidth: root._attachedPanelVisibleWidth
        shellHeight: root._overlayShellHeight
        shellY: root._overlayShellY
        surfaceOpacity: root._attachedPanelOpacity
        surfaceScale: root._attachedSurfaceScale
        pillWidth: _pillClip.width
        pillHeight: root._attachedShellPillHeight
        panelWidth: root._attachedPanelBodyWidth
        panelY: _overlayPanelHost.y
        attachmentOverlap: root._overlayAttachmentOverlap
        shellRadius: root._overlayShellRadius
        bridgeOutset: root._overlayBridgeOutset
        inwardCornerRadius: root._overlayInwardCornerRadius
        pulseOpacity: root._attachedPulseOpacity
        surfaceFillOpacity: root._attachedShellFillOpacity
    }

    // Bar-expanded lower background must live outside the clipped panel host so pulse and spring remain visible.
    Item {
        id: _barExpandedPanelSurfaceHost

        x: _overlayPanelHost.x
        y: _overlayPanelHost.y
        width: _overlayPanelHost.width
        height: _overlayPanelHost.height
        visible: root._barExpandedHintActive && _overlayPanelHost.visible
        z: _overlayPanelHost.z - 1
        opacity: root._attachedPanelOpacity
        scale: root._attachedSurfaceScale
        transformOrigin: Item.Top

        // Detached panel path owns the visible lower workspace body.
        Shape {
            id: _barExpandedPanelSurface
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            // Detached panel path keeps the title seam square and the lower corners rounded.
            ShapePath {
                fillColor: root._barExpandedPanelSurfaceColor
                strokeWidth: 0
                startX: 0
                startY: 0

                PathLine {
                    x: _barExpandedPanelSurface.width
                    y: 0
                }

                PathLine {
                    x: _barExpandedPanelSurface.width
                    y: _barExpandedPanelSurface.height - root._barExpandedDetachedRadius
                }

                PathArc {
                    x: _barExpandedPanelSurface.width - root._barExpandedDetachedRadius
                    y: _barExpandedPanelSurface.height
                    radiusX: root._barExpandedDetachedRadius
                    radiusY: root._barExpandedDetachedRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: root._barExpandedDetachedRadius
                    y: _barExpandedPanelSurface.height
                }

                PathArc {
                    x: 0
                    y: _barExpandedPanelSurface.height - root._barExpandedDetachedRadius
                    radiusX: root._barExpandedDetachedRadius
                    radiusY: root._barExpandedDetachedRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
    }

    // Shared clock layer carries persistent media during hint motion.
    Loader {
        id: _barExpandedSharedClockLoader

        property var eventData: root._barExpandedSharedClockEvent
        property string resolvedIcon: root._resolvedIconSource(eventData.icon || "")
        property date currentTime: root.currentTime
        property bool hasPendingEvents: _cardRegistry.hasPendingEvents
        property int cardHeight: root._barExpandedSharedClockHeight

        anchors.horizontalCenter: _overlayPanelHost.horizontalCenter
        active: root._detachedHintActive
        visible: active
        y: root._barExpandedSharedClockY
        opacity: root._barExpandedSharedClockOpacity
        scale: root._barExpandedSharedClockScale
        z: _overlayPanelHost.z + 2
        transformOrigin: Item.Top
        sourceComponent: _cardRegistry.componentForEvent(eventData, false)
    }

    BarPanels.AttachedExpansionPanelHost {
        id: _overlayPanelHost

        anchorItem: _pillClip
        active: root._attachedPanelActive
        collapseTailHidden: root._attachedCollapseTailHidden
        expanded: root._attachedPanelExpanded
        visibleWidth: root._attachedPanelVisibleWidth
        panelWidth: root._attachedPanelBodyWidth
        visibleHeight: root._attachedPanelVisibleHeight
        detachedY: root._overlayDetachedY
        attachmentOverlap: root._overlayAttachmentOverlap
        revealLift: root._overlayRevealLift
        revealYOffset: root._attachedRevealYOffset
        throwOffsetY: root._pillThrowOffsetY
        surfaceOpacity: root._attachedPanelOpacity
        surfaceScale: root._attachedSurfaceScale
        contentOpacity: root._attachedContentOpacity

        // Attached content stays clipped inside the reveal host.
        IslandCards.SuperIslandAttachedContentDeck {
            id: _attachedContentDeck

            anchors.fill: parent
            active: root._attachedPanelActive
            overlaySessionActive: root._overlaySessionActive
            overlayHintHandoffActive: root._overlayHintHandoffActive
            detachedHintActive: root._detachedHintActive
            showOverlayHandoffHint: root._showOverlayHandoffHint
            hintEvent: root._attachedHintEvent
            handoffHintEvent: root._overlayHandoffHintEvent
            sharedClockActive: root._barExpandedSharedClockVisible
        }
    }

    // Non-clipped seam arc layer keeps the decorative outer corners visible.
    Item {
        x: _overlayPanelHost.x
        y: _overlayPanelHost.y
        width: _overlayPanelHost.width
        height: root._barExpandedSeamArcRadius
        visible: root._barExpandedHintActive
            && !root._barExpandedTitleWidthClamped
            && _overlayPanelHost.visible
            && root._barExpandedSeamArcProgress > 0.01
        z: _overlayPanelHost.z + 1
        opacity: root._attachedPanelOpacity
        scale: root._attachedSurfaceScale
        transformOrigin: Item.Top

        // Left seam arc restores the outer silhouette without rounding the seam itself.
        Canvas {
            id: _leftSeamArcCanvas
            x: -root._barExpandedSeamArcRadius * root._barExpandedSeamArcProgress
                + (1 - root._barExpandedSeamArcProgress) * root._barExpandedTopRadius
            y: 0
            width: root._barExpandedSeamArcRadius
            height: root._barExpandedSeamArcRadius
            visible: root._barExpandedSeamArcProgress > 0.01
            property color canvasFill: root._barExpandedPanelSurfaceColor

            onCanvasFillChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = canvasFill
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width, height)
                ctx.arc(0, height, width, 0, -Math.PI / 2, true)
                ctx.fill()
            }
        }

        // Right seam arc mirrors the same outer contour on the opposite side.
        Canvas {
            id: _rightSeamArcCanvas
            x: parent.width
                - root._barExpandedSeamArcRadius * (1 - root._barExpandedSeamArcProgress)
                - (1 - root._barExpandedSeamArcProgress) * root._barExpandedTopRadius
            y: 0
            width: root._barExpandedSeamArcRadius
            height: root._barExpandedSeamArcRadius
            visible: root._barExpandedSeamArcProgress > 0.01
            property color canvasFill: root._barExpandedPanelSurfaceColor

            onCanvasFillChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = canvasFill
                ctx.beginPath()
                ctx.moveTo(width, 0)
                ctx.lineTo(0, 0)
                ctx.lineTo(0, height)
                ctx.arc(width, height, width, Math.PI, Math.PI * 1.5, false)
                ctx.fill()
            }
        }
    }

    IslandCards.ExpandedPanelDeck {
        id: _overlayDeckHost

        width: root._overlayExpandedWidth
        visible: false
        enabled: false
        drawSurface: false
        measurementMode: false
        activatePages: false
    }

    Loader {
        id: _detachedHintMeasureLoader
        property var eventData: root._attachedHintEvent

        active: root._attachedHintVisible
        visible: false
        enabled: false
        sourceComponent: _cardRegistry.windowHintMeasureCardComponent
    }

    Loader {
        id: _barExpandedMainMeasureLoader
        property var eventData: root._attachedHintEvent

        active: root._attachedHintVisible && root._barExpandedHintActive
        visible: false
        enabled: false
        sourceComponent: _cardRegistry.windowHintBarExpandedMainMeasureCardComponent
    }

    Loader {
        id: _detachedHintDetachedMeasureLoader
        property var eventData: root._attachedHintEvent

        active: root._attachedHintVisible && root._barExpandedHintActive
        visible: false
        enabled: false
        sourceComponent: _cardRegistry.windowHintBarExpandedDetachedMeasureCardComponent
    }

    Loader {
        id: _idleMeasureLoader

        active: true
        visible: false
        enabled: false
        sourceComponent: _cardRegistry.idleComponent
    }

    Loader {
        id: _overlayDeckMeasureLoader

        width: root._overlayExpandedWidth
        active: root._controlCenterOverlayMode
        visible: false
        enabled: false
        sourceComponent: _cardRegistry.overlayDeckMeasureComponent
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root._overlaySessionActive
        onActivated: {
            if (IslandOverlayService.mode === "session-control") {
                SessionControlService.handleEscape()
                return
            }

            IslandOverlayService.closeOverlay("super-island-shortcut")
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !BarLayoutService.suppressWidgetPrimaryActions
            && !root._overlaySessionActive
            && !root._attachedPanelActive
        onClicked: {
            IslandOverlayService.toggleOverlay(root._preferredOverlayPage(), "super-island", "")
        }
    }
}
