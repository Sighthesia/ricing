import Quickshell
import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import "." as IslandParts
import "./IslandWindowHintCardLogic.js" as HintLogic

// Thin composition root for the SuperIsland window hint.
Item {
    id: root

    required property var event
    property bool measurementMode: false
    property var hintData: null
    property real titleCapsuleRevealProgress: 1
    property real outgoingClockOpacity: 0
    property real outgoingClockOffsetY: 0
    property real relocatedClockOpacity: 1
    property real relocatedClockOffsetY: 0
    property bool sharedClockActive: false

    readonly property string presentationMode: root.event && root.event.presentation ? root.event.presentation : "window-hint"
    readonly property bool _defaultPresentation: _windowHintSceneItem ? _windowHintSceneItem.defaultPresentation : false
    readonly property bool _barExpandedCombinedPresentation: _windowHintSceneItem ? _windowHintSceneItem.barExpandedCombinedPresentation : false
    readonly property bool _barExpandedMainPresentation: _windowHintSceneItem ? _windowHintSceneItem.barExpandedMainPresentation : false
    readonly property bool _barExpandedDetachedPresentation: _windowHintSceneItem ? _windowHintSceneItem.barExpandedDetachedPresentation : false
    readonly property real relocatedClockRowY: _windowHintSceneItem.relocatedClockRowY
    readonly property real relocatedClockCenterY: _windowHintSceneItem.relocatedClockCenterY

    readonly property bool _hostKeepsHintVisible: !!(root.event && root.event.type === "window-hint")

    function _resolvedMeasurementHint() {
        const baseHint = root.hintData || WindowHintService.activeHint || root.event || {}
        return Object.assign({}, baseHint, {
            presentation: root.presentationMode !== "" ? root.presentationMode : (baseHint.presentation || "window-hint")
        })
    }

    readonly property var _liveHint: root.measurementMode ? root._resolvedMeasurementHint() : WindowHintService.activeHint
    property var _renderHint: null
    property date currentTime: new Date()
    readonly property var _hint: root._renderHint || root._liveHint
    property real _switchPulseScale: 1
    property real _switchPulseOpacity: 0
    readonly property color _switchPulseFill: HintLogic.mixColor(root._stageFill, Colors.highlight, root._switchPulseOpacity)

    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _padV: Theme.barWidget.contentPaddingV
    readonly property int _rowGap: ThemeSuperIsland.windowHintRowGap
    readonly property int _capsuleGap: ThemeSuperIsland.windowHintCapsuleGap
    readonly property int _workspaceColumnGap: ThemeSuperIsland.windowHintWorkspaceColumnGap
    readonly property int _stagePadH: ThemeSuperIsland.windowHintStagePadH
    readonly property int _stagePadV: ThemeSuperIsland.windowHintStagePadV
    readonly property int _compactIcon: Math.max(10, Theme.barWidget.compactIconSize - 1)
    readonly property int _primaryIcon: Theme.barWidget.primaryIconSize
    readonly property int _workspaceSideWidth: ThemeSuperIsland.windowHintWorkspaceSideWidth
    readonly property int _workspacePrimaryWidth: ThemeSuperIsland.windowHintWorkspacePrimaryWidth
    readonly property int _titleSideWidth: ThemeSuperIsland.windowHintTitleSideWidth
    readonly property int _titlePrimaryWidth: ThemeSuperIsland.windowHintTitlePrimaryWidth
    readonly property int _workspaceSideHeight: ThemeSuperIsland.windowHintWorkspaceSideHeight
    readonly property int _workspacePrimaryHeight: ThemeSuperIsland.windowHintWorkspacePrimaryHeight
    readonly property int _titleCapsuleHeight: ThemeSuperIsland.windowHintTitleCapsuleHeight
    readonly property int _minPreviewWidth: ThemeSuperIsland.windowHintMinPreviewWidth
    readonly property int _maxPreviewWidth: ThemeSuperIsland.windowHintMaxPreviewWidth
    readonly property color _stageFill: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.02)
    readonly property color _stageBorder: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.035)
    readonly property color _primaryCapsuleFill: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.09)
    readonly property color _secondaryCapsuleFill: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.04)
    readonly property var _slotIndices: [-1, 0, 1]
    readonly property real _overflowSlotPosition: 1.18
    readonly property int _workspaceStageWidth: Math.max(root._workspacePrimaryWidth, root._workspaceSideWidth)
    readonly property int _workspaceStageHeight: root._workspaceSideHeight * 2 + root._workspacePrimaryHeight + root._workspaceColumnGap * 2
    readonly property var _workspaceHintLayout: HintLogic.workspaceStageLayoutForHint(root._hint)
    readonly property real _workspaceSingleSideTrim: root._workspaceSideHeight + root._workspaceColumnGap
    readonly property int _workspaceCount: HintLogic.visibleWorkspaceCountForHint(root._hint)
    readonly property bool _workspaceHasBefore: root._workspaceHintLayout.hasBefore
    readonly property bool _workspaceHasAfter: root._workspaceHintLayout.hasAfter
    readonly property real _workspaceSingleSideOffset:
        root._workspaceCount <= 1 || (root._workspaceHasBefore && root._workspaceHasAfter)
            ? 0
            : ((Math.max(0, Math.min(1, root._animatedWorkspaceAnchor - (root._workspaceCount - 2)))
                - Math.max(0, Math.min(1, 1 - root._animatedWorkspaceAnchor)))
                * root._workspaceSingleSideTrim / 2)
    readonly property real _workspaceBottomInset: HintLogic.workspaceBottomInset(root)
    readonly property real _workspaceLeadingTrimTarget:
        root._workspaceHasBefore && root._workspaceHasAfter
            ? 0
            : (root._workspaceHasBefore || root._workspaceHasAfter
                ? root._workspaceSingleSideTrim / 2
                : root._workspaceSingleSideTrim)
    readonly property real _workspaceTrailingTrimTarget:
        root._workspaceHasBefore && root._workspaceHasAfter
            ? 0
            : (root._workspaceHasBefore || root._workspaceHasAfter
                ? root._workspaceSingleSideTrim / 2
                : root._workspaceSingleSideTrim)
    readonly property real _workspaceBaseVisibleStageHeight: root._workspaceStageHeight - root._workspaceLeadingTrim - root._workspaceTrailingTrim
    readonly property real _workspaceVisibleStageHeight: root._workspaceBaseVisibleStageHeight + root._workspaceBottomInset
    readonly property int _titleStageWidth: root._titleSideWidth * 2 + root._titlePrimaryWidth + root._capsuleGap * 2
    readonly property int _titleStageHeight: root._titleCapsuleHeight
    readonly property int _barExpandedTitleCapsuleHeight: Theme.barHeight
    readonly property int _barExpandedDetachedClockHeight: Theme.barWidget.pillHeight
    readonly property int _barExpandedDetachedContentHeight: root._workspaceVisibleStageHeight + root._rowGap + root._barExpandedDetachedClockHeight
    readonly property int _barExpandedCombinedHeight: Theme.barHeight + root._barExpandedDetachedContentHeight
    readonly property real _barExpandedShellRadius: Math.max(Theme.cornerRadius, Theme.screenCornerRadius)
    readonly property int _barExpandedNotchRadius: ThemeSuperIsland.windowHintNotchRadius
    readonly property int _barExpandedNotchHeight: root._barExpandedNotchRadius
    readonly property int _barExpandedExclusivePushPadding: ThemeSuperIsland.windowHintExclusivePushPadding
    readonly property int _barExpandedMainWidth:
        Math.max(
            root._barExpandedDetachedWidth,
            root._minPreviewWidth,
            root._expandedTitleRowWidth + root._padH * 2 + root._stagePadH * 2
        )
    readonly property int _barExpandedDetachedWidth: root._workspaceStageWidth + root._padH * 2 + root._stagePadH * 2
    readonly property real _expandedTitleRowWidth:
        Math.max(
            root._titleSideWidth,
            _windowHintSceneItem ? _windowHintSceneItem.titleRowImplicitWidth : 0
        )
    readonly property var _persistentStageSlotIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    readonly property int _workspaceAnchorBaseDuration: Math.max(150, Math.round(Theme.anim.moveDuration * 1.05))
    readonly property int _titleAnchorBaseDuration: Math.max(140, Theme.anim.moveDuration)
    readonly property int _anchorDurationStep: Math.max(16, Math.round(Theme.anim.moveDuration * 0.1))
    readonly property int _anchorMaximumDuration: Math.max(190, Math.round(Theme.anim.moveDuration * 1.35))
    readonly property int _workspaceTrimDuration: Math.max(90, Math.round(Theme.anim.moveDuration * 0.72))
    readonly property int _workspaceCapsuleOpacityDuration: Math.max(90, Math.round(Theme.anim.moveDuration * 0.72))
    readonly property int _workspaceFocusLeadDuration: Math.max(70, Math.round(Theme.anim.moveDuration * 0.42))
    readonly property int _workspaceFocusTrailDuration: Math.max(240, Math.round(Theme.anim.moveDuration * 1.45))
    readonly property real _combinedBackdropOffsetY:
        root._barExpandedCombinedPresentation
            ? (1 - root.titleCapsuleRevealProgress) * Math.max(6, Theme.barWidget.contentPaddingV * 1.5)
            : 0

    property real _animatedWorkspaceAnchor: -1
    property real _animatedTitleAnchor: -1
    property real _workspaceAnchorTarget: -1
    property real _titleAnchorTarget: -1
    property int _workspaceAnchorDuration: root._workspaceAnchorBaseDuration
    property int _titleAnchorDuration: root._titleAnchorBaseDuration
    property bool _workspaceAnchorAnimationEnabled: true
    property bool _titleAnchorAnimationEnabled: true
    property real _workspaceLeadingTrim: 0
    property real _workspaceTrailingTrim: 0
    property bool _workspaceTrimAnimationEnabled: true
    property bool _workspaceSettlePending: false
    property bool _titleSettlePending: false
    // Inspired by end-4/dots-hyprland ("illogical impulse") workspace indicator motion.
    // Reference: https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/modules/ii/bar/Workspaces.qml
    property int _workspaceFocusIndex: -1
    property var _workspaceStageSlots: root._emptyStageSlots("workspace-slot")
    property var _titleStageSlots: root._emptyStageSlots("title-slot")
    property QtObject _workspaceFocusIndexPair: _workspaceFocusPairState

    implicitWidth: root._barExpandedMainPresentation
        ? root._barExpandedMainWidth
        : (root._barExpandedDetachedPresentation
            ? root._barExpandedDetachedWidth
            : Math.min(root._maxPreviewWidth, Math.max(root._minPreviewWidth, Math.max(root._workspaceStageWidth, root._titleStageWidth) + root._padH * 2 + root._stagePadH * 2)))
    implicitHeight: root._barExpandedMainPresentation
        ? Theme.barHeight
        : (root._barExpandedDetachedPresentation
            ? (root._barExpandedDetachedContentHeight + root._padV * 2 + root._stagePadV * 2)
            : (root._workspaceVisibleStageHeight + root._rowGap + root._titleStageHeight + root._padV * 2 + root._stagePadV * 2))

    function _lerp(from, to, progress) { return HintLogic.lerp(from, to, progress) }
    function _mixColor(from, to, progress) { return HintLogic.mixColor(from, to, progress) }
    function _workspaceLabel(index) { return HintLogic.workspaceLabel(index) }
    function _cloneHint(hint) { return HintLogic.cloneHint(hint) }
    function _emptyStageSlots(prefix) { return HintLogic.emptyStageSlots(root, prefix) }
    function _workspaceStageCapsuleAt(slotIndex) { return HintLogic.workspaceStageCapsuleAt(root, slotIndex) }
    function _workspaceStageAbsoluteIndexAt(slotIndex) { return HintLogic.workspaceStageAbsoluteIndexAt(root, slotIndex) }
    function _titleStageCapsuleAt(slotIndex) { return HintLogic.titleStageCapsuleAt(root, slotIndex) }
    function _workspaceStageSlotPositionAt(slotIndex) { return HintLogic.workspaceStageSlotPositionAt(root, slotIndex) }
    function _titleStageSlotPositionAt(slotIndex) { return HintLogic.titleStageSlotPositionAt(root, slotIndex) }
    function _refreshStageSlots(hint, includeCurrentAnchor, preserveUnassigned) { HintLogic.refreshStageSlots(root, hint, includeCurrentAnchor, preserveUnassigned) }
    function _settleWorkspaceStageSlots(hint) { HintLogic.settleWorkspaceStageSlots(root, hint) }
    function _retireWorkspaceStageSlots(hint) { return HintLogic.retireWorkspaceStageSlots(root, hint) }
    function _cleanupWorkspaceStageSlots(hint) { HintLogic.cleanupWorkspaceStageSlots(root, hint) }
    function _settleTitleStageSlots(hint) { HintLogic.settleTitleStageSlots(root, hint) }
    function _retargetHintAnchors(hint, immediate) { HintLogic.retargetHintAnchors(root, hint, immediate, _workspaceAnchorSettleTimer, _titleAnchorSettleTimer) }
    function _visibleWorkspaceIcons(capsule) { return HintLogic.visibleWorkspaceIcons(capsule) }
    function _focusedWorkspaceIconIndex(capsule) { return HintLogic.focusedWorkspaceIconIndex(capsule) }
    function _workspaceMetrics(slotPosition) { return HintLogic.workspaceMetrics(root, slotPosition, -1) }
    function _workspaceMetricsForSlot(slotPosition, absoluteIndex) { return HintLogic.workspaceMetrics(root, slotPosition, absoluteIndex) }
    function _titleMetrics(slotPosition) { return HintLogic.titleMetrics(root, slotPosition) }

    function _handleHintChange() {
        if (root.measurementMode) {
            _workspaceAnchorSettleTimer.stop()
            _titleAnchorSettleTimer.stop()
            _workspaceStageCleanupTimer.stop()
            root._renderHint = root._cloneHint(root._liveHint)
            root._refreshStageSlots(root._renderHint, false, false)
            root._retargetHintAnchors(root._renderHint, true)
            root._syncWorkspaceStageTrim(true)
            return
        }

        const wasVisible = !!(root._hint && root._hint.visible)
        _workspaceStageCleanupTimer.stop()
        HintLogic.handleHintChange(root, root._liveHint, _workspaceAnchorSettleTimer, _titleAnchorSettleTimer)
        root._syncWorkspaceStageTrim(!wasVisible || !root._hint || !root._hint.visible)
    }

    function _syncWorkspaceStageTrim(immediate) {
        if (immediate) {
            root._workspaceTrimAnimationEnabled = false
            root._workspaceLeadingTrim = root._workspaceLeadingTrimTarget
            root._workspaceTrailingTrim = root._workspaceTrailingTrimTarget
            root._workspaceTrimAnimationEnabled = true
            return
        }

        root._workspaceLeadingTrim = root._workspaceLeadingTrimTarget
        root._workspaceTrailingTrim = root._workspaceTrailingTrimTarget
    }

    function _hintSwitchChanged(previousHint, nextHint) {
        const previous = previousHint || {}
        const next = nextHint || {}

        return (previous.currentWindowId || "") !== (next.currentWindowId || "")
            || (previous.currentIndex !== undefined ? previous.currentIndex : -1)
                !== (next.currentIndex !== undefined ? next.currentIndex : -1)
            || (previous.workspaceId || "") !== (next.workspaceId || "")
            || (previous.workspaceIndex !== undefined ? previous.workspaceIndex : -1)
                !== (next.workspaceIndex !== undefined ? next.workspaceIndex : -1)
            || (previous.activeWorkspacePosition !== undefined ? previous.activeWorkspacePosition : -1)
                !== (next.activeWorkspacePosition !== undefined ? next.activeWorkspacePosition : -1)
    }

    function _triggerSwitchPulse() {
        _switchPulseAnim.stop()
        root._switchPulseScale = 1
        root._switchPulseOpacity = 0
        _switchPulseAnim.start()
    }

    // Clock updates keep the hint snapshot aligned with live time.
    Timer {
        id: _clockTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    // Workspace anchor settling waits for the spring to reach its target.
    Timer {
        id: _workspaceAnchorSettleTimer
        repeat: false
        onTriggered: {
            if (!root._workspaceSettlePending)
                return
            if (Math.abs(root._animatedWorkspaceAnchor - root._workspaceAnchorTarget) > 0.001) {
                interval = 16
                restart()
                return
            }
            root._workspaceSettlePending = false
            if (root._retireWorkspaceStageSlots(root._hint)) {
                _workspaceStageCleanupTimer.interval = root._workspaceCapsuleOpacityDuration + 16
                _workspaceStageCleanupTimer.restart()
                return
            }
            root._cleanupWorkspaceStageSlots(root._hint)
        }
    }

    // Cleanup runs after the workspace exit fade completes.
    Timer {
        id: _workspaceStageCleanupTimer
        repeat: false
        onTriggered: root._cleanupWorkspaceStageSlots(root._hint)
    }

    // Title anchor settling mirrors the workspace motion timing.
    Timer {
        id: _titleAnchorSettleTimer
        repeat: false
        onTriggered: {
            if (!root._titleSettlePending)
                return
            if (Math.abs(root._animatedTitleAnchor - root._titleAnchorTarget) > 0.001) {
                interval = 16
                restart()
                return
            }
            root._titleSettlePending = false
            root._settleTitleStageSlots(root._hint)
        }
    }

    // Workspace anchor animation keeps the stage cover flow smooth.
    Behavior on _animatedWorkspaceAnchor {
        enabled: root._workspaceAnchorAnimationEnabled

        NumberAnimation {
            duration: root._workspaceAnchorDuration
            easing.type: Easing.OutSine
        }
    }

    // Workspace trim animation avoids snapping when edge slots appear or retire.
    Behavior on _workspaceLeadingTrim {
        enabled: root._workspaceTrimAnimationEnabled

        NumberAnimation {
            duration: root._workspaceTrimDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Trailing trim mirrors the same edge-retire motion.
    Behavior on _workspaceTrailingTrim {
        enabled: root._workspaceTrimAnimationEnabled

        NumberAnimation {
            duration: root._workspaceTrimDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Title anchor animation keeps the focused title lane centered during retargets.
    Behavior on _animatedTitleAnchor {
        enabled: root._titleAnchorAnimationEnabled

        NumberAnimation {
            duration: root._titleAnchorDuration
            easing.type: Easing.OutSine
        }
    }

    // Focus pair keeps the workspace highlight stretch animation intact.
    QtObject {
        id: _workspaceFocusPairState

        property int index: root._workspaceFocusIndex
        property real idx1: index
        property real idx2: index
        property int idx1Duration: root._workspaceFocusLeadDuration
        property int idx2Duration: root._workspaceFocusTrailDuration

        Behavior on idx1 {
            NumberAnimation {
                duration: _workspaceFocusPairState.idx1Duration
                easing.type: Easing.OutSine
            }
        }

        Behavior on idx2 {
            NumberAnimation {
                duration: _workspaceFocusPairState.idx2Duration
                easing.type: Easing.OutSine
            }
        }
    }

    onEventChanged: if (root.measurementMode) root._handleHintChange()
    onHintDataChanged: if (root.measurementMode) root._handleHintChange()

    // Live hints update through the service when not in measurement mode.
    Connections {
        target: WindowHintService
        enabled: !root.measurementMode
        function onActiveHintChanged() {
            const previousHint = root._renderHint || root._liveHint
            root._handleHintChange()
            const nextHint = root._renderHint || root._liveHint
            if (root._hintSwitchChanged(previousHint, nextHint) && nextHint && nextHint.visible === true)
                root._triggerSwitchPulse()
        }
    }

    // Clone the render hint once the root is ready.
    Component.onCompleted: {
        root._renderHint = root._cloneHint(root._liveHint)
        root._refreshStageSlots(root._renderHint, false, false)
        root._retargetHintAnchors(root._renderHint, true)
        root._syncWorkspaceStageTrim(true)
    }

    // Whole-card spring and pulse feedback for hint switches.
    SequentialAnimation {
        id: _switchPulseAnim

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_switchPulseScale"
                to: Theme.anim.sharedPulseScale
                duration: Theme.anim.pulseSpringDuration
                easing.type: Theme.anim.pulseSpringType
                easing.overshoot: Theme.anim.pulseSpringOvershoot
            }

            NumberAnimation {
                target: root
                property: "_switchPulseOpacity"
                to: 0.12
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_switchPulseScale"
                to: 1
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }

            NumberAnimation {
                target: root
                property: "_switchPulseOpacity"
                to: 0
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }
    }

    scale: root._switchPulseScale
    transformOrigin: Item.Center

    // Presentation scene owns the visible routing while the card keeps state and snapshot logic.
    IslandParts.IslandWindowHintScene {
        id: _windowHintSceneItem

        anchors.fill: parent
        card: root
    }
}
