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
        barExpandedTitleWidthClamped: root._barExpandedTitleWidthClamped
        pillBackgroundWidth: root._pillSurface ? root._pillSurface.pillBackgroundWidth : 0
        barExpandedDetachedHintWidth: root._barExpandedDetachedHintWidth
        phase: root._phase
        overlayClosing: root._overlayClosing
        attachedRevealProgress: root._attachedRevealProgress
        attachedPanelVisibleHeight: root._attachedPanelVisibleHeight
        windowHintSideHeight: root._windowHintSideHeight
        attachedPulseOpacity: root._attachedPulseOpacity
    }

    // Attached reveal geometry helper owns the derived reveal width, height, and offset progress.
    IslandCards.SuperIslandAttachedRevealGeometry {
        id: _attachedRevealGeometry

        attachedPanelActive: root._attachedPanelActive
        attachedRevealSeedWidth: root._attachedRevealSeedWidth
        attachedPanelRevealWidth: root._attachedPanelRevealWidth
        attachedPanelWidth: root._attachedPanelWidth
        attachedRevealSeedHeight: root._attachedRevealSeedHeight
        attachedPanelRevealHeight: root._attachedPanelRevealHeight
        attachedPanelHeight: root._attachedPanelHeight
        barExpandedHintActive: root._barExpandedHintActive
        overlayRevealLift: root._overlayRevealLift
    }

    // Host measurement geometry helper keeps the exported reservation and reveal contract together.
    IslandCards.SuperIslandHostGeometry {
        id: _hostGeometry
        host: root
    }

    // Track geometry helper keeps return-target and track centering math together.
    IslandCards.SuperIslandTrackGeometry {
        id: _trackGeometry

        host: root
        barExpandedSharedClockTargetCenterYLatched: root._barExpandedSharedClockTargetCenterYLatched
    }

    // Width-chain geometry helper keeps the pure derived width and debug cluster together.
    IslandCards.SuperIslandWidthChainGeometry {
        id: _widthChainGeometry

        host: root
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

    readonly property alias _mainTrackZoneHeight: _trackGeometry.mainTrackZoneHeight
    readonly property alias _mainTrackCenterY: _trackGeometry.mainTrackCenterY
    readonly property alias _flashTrackCenterY: _trackGeometry.flashTrackCenterY
    readonly property alias _flashRowBaseY: _trackGeometry.flashRowBaseY
    readonly property alias _flashLaneCenterY: _trackGeometry.flashLaneCenterY
    readonly property alias _flashStripY: _trackGeometry.flashStripY
    readonly property alias _mainFlashTrackY: _trackGeometry.mainFlashTrackY

    readonly property int _windowHintStagePadV: ThemeSuperIsland.windowHintStagePadV
    readonly property int _windowHintRowGap: ThemeSuperIsland.windowHintRowGap
    readonly property int _windowHintWorkspaceColumnGap: ThemeSuperIsland.windowHintWorkspaceColumnGap
    readonly property int _windowHintSideHeight: ThemeSuperIsland.windowHintWorkspaceSideHeight
    readonly property int _windowHintPrimaryHeight: ThemeSuperIsland.windowHintWorkspacePrimaryHeight
    readonly property int _windowHintTitleHeight: ThemeSuperIsland.windowHintTitleCapsuleHeight

    readonly property alias _hintTrackY: _trackGeometry.hintTrackY
    readonly property real _hintDividerY: root._pillH + Math.max(0, (root._flashGap - 1) / 2)
    readonly property real _hintBackgroundY: root._flashRowBaseY
    readonly property real _hintBackgroundHeight: root._flashRowH
    readonly property real _hintBackgroundPulseOpacity:
        root._hintPhase && !root._isHintEventType(root._flashSourceEvent.type)
            ? root._sharedBackgroundPulseOpacity
            : 0
    readonly property alias _returnTrackCenterY: _trackGeometry.returnTrackCenterY

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
    readonly property alias _barExpandedTailRectReleased: _overlayGeometry.barExpandedTailRectReleased
    readonly property alias _barExpandedSeamArcProgress: _overlayGeometry.barExpandedSeamArcProgress
    // Shell shape properties delegated to the geometry helper.
    readonly property alias _overlayShellRadius: _overlayGeometry.overlayShellRadius
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
    readonly property alias _detachedHintWidth: _widthChainGeometry.detachedHintWidth
    readonly property alias _barExpandedMainHintWidthMeasured: _widthChainGeometry.barExpandedMainHintWidthMeasured
    readonly property alias _barExpandedMainHintWidth: _widthChainGeometry.barExpandedMainHintWidth
    readonly property alias _barExpandedDetachedHintWidth: _widthChainGeometry.barExpandedDetachedHintWidth
    readonly property alias _barExpandedTitleWidthClamped: _widthChainGeometry.barExpandedTitleWidthClamped
    readonly property bool _barExpandedHintActive:
        root._detachedHintActive && root._attachedHintEvent.presentation === "bar-expanded"
    // Bar reservation must follow only the top host footprint; the detached lower panel is visual-only.
    readonly property real _barExpandedHostFootprintWidth: _hostGeometry.barExpandedHostFootprintWidth
    readonly property real layoutReservationWidth: _hostGeometry.layoutReservationWidth
    readonly property real layoutMeasurementWidth: _hostGeometry.layoutMeasurementWidth
    readonly property real layoutContextMenuHeight: _hostGeometry.layoutContextMenuHeight
    readonly property real layoutRevealHeight: _hostGeometry.layoutRevealHeight
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
    readonly property alias _overlayPillBackgroundWidth: _pillSurface.pillBackgroundWidth
    readonly property alias _barExpandedPanelSurfaceColor: _overlayGeometry.barExpandedPanelSurfaceColor

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
    property real _latchedIdleCollapsedWidth: 0
    property real _safeIdleCollapsedWidth: 0
    property bool _barExpandedTitleRevealLatched: false
    readonly property alias _collapsedWidthLive: _widthChainGeometry.collapsedWidthLive
    readonly property alias _idleCollapsedWidthLive: _widthChainGeometry.idleCollapsedWidthLive
    readonly property alias _barExpandedTitleRevealProgress: _widthChainGeometry.barExpandedTitleRevealProgress
    readonly property alias _barExpandedTitleRevealWidthProgress: _widthChainGeometry.barExpandedTitleRevealWidthProgress
    readonly property alias _useAttachedCollapseBaseWidth: _widthChainGeometry.useAttachedCollapseBaseWidth
    readonly property alias _collapsedWidth: _widthChainGeometry.collapsedWidth
    readonly property alias _expandedWidth: _widthChainGeometry.expandedWidth

    readonly property alias _mainTrackEnterY: _trackGeometry.mainTrackEnterY
    readonly property alias _returnWidthLive: _trackGeometry.returnWidthLive
    readonly property alias _returnWidth: _trackGeometry.returnWidth
    readonly property alias _transitionCollapsedWidth: _trackGeometry.transitionCollapsedWidth
    readonly property real _idleOpticalOffset: 0
    readonly property bool _hintPhase: root._phase === "hint" || root._phase === "hint-exit"
    readonly property bool _listensToService: true
    readonly property real _transientAccentBaseOpacity: 0
    readonly property real _overlayReservedExtension:
        root._attachedPanelActive
            ? ((root._barExpandedHintActive
                    && root._phase === "hint-exit"
                    && root._attachedPanelVisibleHeight <= 0)
                ? 0
                : root._overlayDetachedOffset
                    + (root._overlaySessionActive
                        ? root._attachedPanelHeight
                        : root._detachedHintReservedHeight))
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

    readonly property alias _attachedPanelVisibleWidth: _attachedRevealGeometry.attachedPanelVisibleWidth
    readonly property alias _attachedPanelVisibleHeight: _attachedRevealGeometry.attachedPanelVisibleHeight
    readonly property alias _attachedWidthRevealProgress: _attachedRevealGeometry.attachedWidthRevealProgress
    readonly property alias _attachedHeightRevealProgress: _attachedRevealGeometry.attachedHeightRevealProgress
    readonly property alias _attachedRevealProgress: _attachedRevealGeometry.attachedRevealProgress
    readonly property alias _attachedVerticalRevealProgress: _attachedRevealGeometry.attachedVerticalRevealProgress
    readonly property alias _attachedRevealYOffset: _attachedRevealGeometry.attachedRevealYOffset
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
    readonly property alias _barExpandedSharedClockLandingY: _trackGeometry.barExpandedSharedClockLandingY
    readonly property alias _barExpandedSharedClockStartCenterY: _trackGeometry.barExpandedSharedClockStartCenterY
    readonly property alias _barExpandedSharedClockStartY: _trackGeometry.barExpandedSharedClockStartY
    readonly property alias _barExpandedSharedClockTargetCenterY: _trackGeometry.barExpandedSharedClockTargetCenterY
    property real _barExpandedSharedClockTargetCenterYLatched: 0
    readonly property alias _barExpandedSharedClockTargetY: _trackGeometry.barExpandedSharedClockTargetY
    readonly property alias _barExpandedSharedClockBaseY: _trackGeometry.barExpandedSharedClockBaseY
    readonly property alias _barExpandedSharedClockY: _trackGeometry.barExpandedSharedClockY
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
            root._latchIdleCollapsedWidthForBarExpandedHint()
            root._barExpandedSharedClockEvent = root._baselineEvent
            const baseWidth = Math.max(0, _pillTransitionControl.animatedWidth)
            root._barExpandedEntryBaseWidth = baseWidth
            root._barExpandedExitBaseWidth = baseWidth
            root._barExpandedTitleRevealLatched = false
            root._hintRevealSettled = false
            return
        }

        root._latchedIdleCollapsedWidth = 0
        root._barExpandedEntryBaseWidth = 0
        root._barExpandedExitBaseWidth = 0
        root._barExpandedTitleRevealLatched = false
        root._hintRevealSettled = false
    }
    on_BarExpandedSharedClockVisibleChanged: {
        if (!root._barExpandedSharedClockVisible) {
            root._releaseBarExpandedSharedClockReturnTarget()
        }
    }
    on_CollapsedWidthChanged: root._syncLatchedIdleCollapsedWidth(false)
    on_IdleCollapsedWidthLiveChanged: root._syncLatchedIdleCollapsedWidth(false)
    on_PillAnimatedWidthChanged: root._syncLatchedIdleCollapsedWidth(false)
    on_MainDisplayEventChanged: root._syncLatchedIdleCollapsedWidth(false)
    on_AttachedPanelActiveChanged: root._syncLatchedIdleCollapsedWidth(false)
    on_HintRevealSettledChanged: {
        if (!root._barExpandedHintActive || !root._hintRevealSettled)
            return

        root._barExpandedEntryBaseWidth = 0
        root._barExpandedTitleRevealLatched = true
    }
    on_PhaseChanged: {
        if (root._phase === "hint-exit" && root._barExpandedHintActive) {
            root._latchBarExpandedSharedClockReturnTarget()
        }

        root._syncLatchedIdleCollapsedWidth(false)
        root._syncBarExpandedExitBaseWidth()
    }
    on_AttachedPanelWidthChanged: root._retargetAttachedPanelWidthIfNeeded()
    on_AttachedPanelHeightChanged: {
        _stateMachine.syncOverlayExtensionReservation()
        root._retargetAttachedPanelHeightIfNeeded()
    }
    on_AttachedPanelVisibleHeightChanged: {
        _stateMachine.syncOverlayExtensionReservation()
    }
    on_AttachedPanelVisibleWidthChanged: root._syncBarExpandedExitBaseWidth()
    on_DetachedHintActiveChanged: {
        root._syncDetachedHintSessionHeight()
    }
    on_AttachedCollapseAnimatingChanged: {
        root._syncDetachedHintSessionHeight()
    }
    on_DetachedHintHeightChanged: {
        root._syncDetachedHintSessionHeight()
    }
    on_BarExpandedDetachedHintHeightChanged: {
        root._syncDetachedHintSessionHeight()
    }

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

    function _safeIdleCollapsedWidthCandidate() {
        const minimumUsefulWidth = root._padH * 2
        const safeIdleState = root._phase === "idle"
            && !root._barExpandedHintActive
            && !root._attachedPanelActive
            && (!root._mainDisplayEvent || root._mainDisplayEvent.type === "idle")

        if (!safeIdleState)
            return 0

        return Math.max(
            0,
            root._collapsedWidth > minimumUsefulWidth ? root._collapsedWidth : 0,
            root._pillAnimatedWidth > minimumUsefulWidth ? root._pillAnimatedWidth : 0
        )
    }

    function _refreshSafeIdleCollapsedWidth() {
        const candidateWidth = Math.max(0, root._safeIdleCollapsedWidthCandidate())

        if (candidateWidth <= root._padH * 2)
            return

        root._safeIdleCollapsedWidth = candidateWidth
    }

    function _syncLatchedIdleCollapsedWidth(forceDuringHint) {
        root._refreshSafeIdleCollapsedWidth()

        const candidateWidth = Math.max(0, root._safeIdleCollapsedWidth)
        const minimumUsefulWidth = root._padH * 2
        const missingLatchedWidth = root._latchedIdleCollapsedWidth <= minimumUsefulWidth

        if (candidateWidth <= minimumUsefulWidth)
            return

        if (root._barExpandedHintActive && !forceDuringHint && !missingLatchedWidth)
            return

        root._latchedIdleCollapsedWidth = candidateWidth
    }

    function _latchIdleCollapsedWidthForBarExpandedHint() {
        root._syncLatchedIdleCollapsedWidth(true)

        const fallbackThreshold = root._padH * 2
        const candidateWidth = Math.max(0, root._safeIdleCollapsedWidth)

        if (candidateWidth <= fallbackThreshold)
            return

        root._latchedIdleCollapsedWidth = Math.max(root._latchedIdleCollapsedWidth, candidateWidth)
    }

    function _latchBarExpandedSharedClockReturnTarget() {
        root._barExpandedSharedClockTargetCenterYLatched = root._barExpandedSharedClockTargetCenterY
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

    function _syncPillToCollapsed() {
        if (root._pillTransition && typeof root._pillTransition.snapToCollapsed === "function")
            root._pillTransition.snapToCollapsed()
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
            pillExpanded: root._pillExpanded,
            collapsedWidthLive: Math.round(root._collapsedWidthLive || 0),
            collapsedWidth: Math.round(root._collapsedWidth || 0),
            idleCollapsedWidthLive: Math.round(root._idleCollapsedWidthLive || 0),
            safeIdleCollapsedWidth: Math.round(root._safeIdleCollapsedWidth || 0),
            latchedIdleCollapsedWidth: Math.round(root._latchedIdleCollapsedWidth || 0),
            transitionCollapsedWidth: Math.round(root._transitionCollapsedWidth || 0),
            expandedWidth: Math.round(root._expandedWidth || 0),
            barExpandedExitBaseWidth: Math.round(root._barExpandedExitBaseWidth || 0),
            barExpandedTitleRevealProgress: Number((root._barExpandedTitleRevealProgress || 0).toFixed(3)),
            barExpandedTitleRevealWidthProgress: Number((root._barExpandedTitleRevealWidthProgress || 0).toFixed(3)),
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
            source: source || "",
            returnSession: hasReturnSession ? root._windowHintReturnSession : 0,
            returnStep: returnStep,
            phase: root._phase,
            attachedHintType: root._attachedHintEvent && root._attachedHintEvent.type ? root._attachedHintEvent.type : "",
            attachedHintPresentation: root._attachedHintEvent && root._attachedHintEvent.presentation ? root._attachedHintEvent.presentation : "",
            barExpandedHintActive: root._barExpandedHintActive,
            hostFootprintWidth: Math.round(root._barExpandedHostFootprintWidth || 0),
            layoutMeasurementWidth: Math.round(root.layoutMeasurementWidth || 0),
            layoutReservationWidth: Math.round(root.layoutReservationWidth || 0),
            expandedWidth: Math.round(root._expandedWidth || 0),
            collapsedWidth: Math.round(root._collapsedWidth || 0),
            transitionCollapsedWidth: Math.round(root._transitionCollapsedWidth || 0),
            collapsedWidthLive: Math.round(root._collapsedWidthLive || 0),
            idleCollapsedWidthLive: Math.round(root._idleCollapsedWidthLive || 0),
            safeIdleCollapsedWidth: Math.round(root._safeIdleCollapsedWidth || 0),
            latchedIdleCollapsedWidth: Math.round(root._latchedIdleCollapsedWidth || 0),
            barExpandedExitBaseWidth: Math.round(root._barExpandedExitBaseWidth || 0),
            barExpandedTitleRevealProgress: Number((root._barExpandedTitleRevealProgress || 0).toFixed(3)),
            barExpandedTitleRevealWidthProgress: Number((root._barExpandedTitleRevealWidthProgress || 0).toFixed(3)),
            attachedPanelRevealWidth: Math.round(root._attachedPanelRevealWidth || 0),
            attachedPanelVisibleWidth: Math.round(root._attachedPanelVisibleWidth || 0),
            attachedCollapseAnimating: root._attachedCollapseAnimating,
            barExpandedDetachedHintWidth: Math.round(root._barExpandedDetachedHintWidth || 0),
            barExpandedMainHintWidth: Math.round(root._barExpandedMainHintWidth || 0),
            barExpandedMainHintWidthMeasured: Math.round(root._barExpandedMainHintWidthMeasured || 0),
            attachedCollapseBaseWidth: Math.round(root._attachedCollapseBaseWidth || 0),
            pillAnimatedWidth: Math.round(root._pillAnimatedWidth || 0),
            implicitWidth: Math.round(root.implicitWidth || 0),
            mainType: root._mainDisplayEvent && root._mainDisplayEvent.type ? root._mainDisplayEvent.type : "",
            flashType: root._flashSourceEvent && root._flashSourceEvent.type ? root._flashSourceEvent.type : ""
        }

        const signature = JSON.stringify(snapshot)
        if (signature === root._lastWindowHintReturnDebugSignature)
            return

        if (hasReturnSession)
            root._windowHintReturnStep = returnStep

        root._lastWindowHintReturnDebugSignature = signature
        console.log("[DymicShell:SuperIslandReturn]", signature)
    }

    function _logReservationChain(context) {
        if (!root._debugLogging)
            return

        console.log("[DymicShell:SuperIslandReservation]", JSON.stringify({
            label: root.debugInstanceLabel,
            context: context || "",
            phase: root._phase,
            barExpandedHintActive: root._barExpandedHintActive,
            overlaySessionActive: root._overlaySessionActive,
            overlayClosing: root._overlayClosing,
            overlayReservedExtension: Math.round(root._overlayReservedExtension || 0),
            attachedPanelHeight: Math.round(root._attachedPanelHeight || 0),
            attachedPanelVisibleHeight: Math.round(root._attachedPanelVisibleHeight || 0),
            detachedHintReservedHeight: Math.round(root._detachedHintReservedHeight || 0),
            latchedDetachedHintSessionHeight: Math.round(root._latchedDetachedHintSessionHeight || 0),
            layoutRevealHeight: Math.round(root.layoutRevealHeight || 0),
            layoutMeasurementWidth: Math.round(root.layoutMeasurementWidth || 0),
            layoutContextMenuHeight: Math.round(root.layoutContextMenuHeight || 0)
        }))
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

        // Shared pill chrome keeps the visible bar surface and pulse layers together.
        IslandCards.SuperIslandPillSurface {
            id: _pillSurface

            host: root
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
    IslandCards.SuperIslandSeamArcLayer {
        id: _seamArcLayer

        host: root
        panelHost: _overlayPanelHost
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
        anchors.fill: _pillClip
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
