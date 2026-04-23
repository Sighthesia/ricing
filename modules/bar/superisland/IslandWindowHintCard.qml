import Quickshell
import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import "." as IslandParts
import "./IslandWindowHintCardLogic.js" as HintLogic

// Renders the SuperIsland window hint with slot-driven workspace and title motion.
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
    readonly property string presentationMode: root.event && root.event.presentation ? root.event.presentation : "window-hint"
    readonly property bool _barExpandedCombinedPresentation: root.presentationMode === "bar-expanded"
    readonly property bool _barExpandedMainPresentation: root.presentationMode === "bar-expanded-main"
    readonly property bool _barExpandedDetachedPresentation: root.presentationMode === "bar-expanded-detached"
    readonly property bool _defaultPresentation:
        !root._barExpandedCombinedPresentation
        && !root._barExpandedMainPresentation
        && !root._barExpandedDetachedPresentation

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
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _padV: Theme.barWidget.contentPaddingV
    readonly property int _rowGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _capsuleGap: Math.max(4, Math.round(5 * Theme.uiScale))
    readonly property int _workspaceColumnGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _stagePadH: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _stagePadV: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _compactIcon: Math.max(10, Theme.barWidget.compactIconSize - 1)
    readonly property int _primaryIcon: Theme.barWidget.primaryIconSize
    readonly property int _workspaceSideWidth: Math.round(164 * Theme.uiScale)
    readonly property int _workspacePrimaryWidth: Math.round(300 * Theme.uiScale)
    readonly property int _titleSideWidth: Math.round(132 * Theme.uiScale)
    readonly property int _titlePrimaryWidth: Math.round(292 * Theme.uiScale)
    readonly property int _workspaceSideHeight: Math.max(24, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV)
    readonly property int _workspacePrimaryHeight: Math.max(54, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 7)
    readonly property int _titleCapsuleHeight: Math.max(30, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 6)
    readonly property int _minPreviewWidth: Math.round(320 * Theme.uiScale)
    readonly property int _maxPreviewWidth: Math.round(560 * Theme.uiScale)
    readonly property color _stageFill: Qt.rgba(1, 1, 1, 0.02)
    readonly property color _stageBorder: Qt.rgba(1, 1, 1, 0.035)
    readonly property color _primaryCapsuleFill: Qt.rgba(1, 1, 1, 0.09)
    readonly property color _secondaryCapsuleFill: Qt.rgba(1, 1, 1, 0.04)
    readonly property var _slotIndices: [-1, 0, 1]
    readonly property real _overflowSlotPosition: 1.18
    readonly property int _workspaceStageWidth: Math.max(root._workspacePrimaryWidth, root._workspaceSideWidth)
    readonly property int _workspaceStageHeight: root._workspaceSideHeight * 2 + root._workspacePrimaryHeight + root._workspaceColumnGap * 2
    readonly property var _workspaceHintLayout: HintLogic.workspaceStageLayoutForHint(root._hint)
    readonly property real _workspaceSingleSideTrim: root._workspaceSideHeight + root._workspaceColumnGap
    readonly property int _workspaceCount:
        HintLogic.visibleWorkspaceCountForHint(root._hint)
    readonly property bool _workspaceHasBefore:
        root._workspaceHintLayout.hasBefore
    readonly property bool _workspaceHasAfter:
        root._workspaceHintLayout.hasAfter
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
    readonly property int _barExpandedDetachedContentHeight:
        root._workspaceVisibleStageHeight + root._rowGap + root._barExpandedDetachedClockHeight
    readonly property int _barExpandedCombinedHeight:
        Theme.barHeight + root._barExpandedDetachedContentHeight
    readonly property real _barExpandedShellRadius:
        Math.max(Theme.cornerRadius, Theme.screenCornerRadius)
    readonly property int _barExpandedNotchRadius: Math.max(10, Math.round(16 * Theme.uiScale))
    readonly property int _barExpandedNotchHeight: root._barExpandedNotchRadius
    readonly property int _barExpandedExclusivePushPadding: Math.max(0, Theme.widgetSpacing)
    readonly property int _barExpandedMainWidth:
        Math.max(
            root._barExpandedDetachedWidth,
            root._minPreviewWidth,
            root._expandedTitleRowWidth + root._barExpandedExclusivePushPadding * 2
        )
    readonly property int _barExpandedDetachedWidth:
        root._workspaceStageWidth + root._padH * 2 + root._stagePadH * 2
    readonly property real _expandedTitleRowWidth:
        Math.max(
            root._titleSideWidth,
            _barExpandedCombinedTitleRow ? _barExpandedCombinedTitleRow.implicitWidth : 0,
            _barExpandedMainTitleRow ? _barExpandedMainTitleRow.implicitWidth : 0
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

    implicitWidth: root._barExpandedMainPresentation
        ? root._barExpandedMainWidth
        : (root._barExpandedDetachedPresentation
            ? root._barExpandedDetachedWidth
            : Math.min(
                root._maxPreviewWidth,
                Math.max(
                    root._minPreviewWidth,
                    Math.max(root._workspaceStageWidth, root._titleStageWidth) + root._padH * 2 + root._stagePadH * 2
                )
            ))
    implicitHeight: root._barExpandedMainPresentation
        ? Theme.barHeight
        : (root._barExpandedDetachedPresentation
            ? (root._barExpandedDetachedContentHeight + root._padV * 2 + root._stagePadV * 2)
            : (root._workspaceVisibleStageHeight + root._rowGap + root._titleStageHeight + root._padV * 2 + root._stagePadV * 2))

    function _lerp(from, to, progress) {
        return HintLogic.lerp(from, to, progress)
    }

    function _mixColor(from, to, progress) {
        return HintLogic.mixColor(from, to, progress)
    }

    function _workspaceLabel(index) {
        return HintLogic.workspaceLabel(index)
    }

    function _cloneHint(hint) {
        return HintLogic.cloneHint(hint)
    }

    function _emptyStageSlots(prefix) {
        return HintLogic.emptyStageSlots(root, prefix)
    }

    function _workspaceStageCapsuleAt(slotIndex) {
        return HintLogic.workspaceStageCapsuleAt(root, slotIndex)
    }

    function _workspaceStageAbsoluteIndexAt(slotIndex) {
        return HintLogic.workspaceStageAbsoluteIndexAt(root, slotIndex)
    }

    function _titleStageCapsuleAt(slotIndex) {
        return HintLogic.titleStageCapsuleAt(root, slotIndex)
    }

    function _workspaceStageSlotPositionAt(slotIndex) {
        return HintLogic.workspaceStageSlotPositionAt(root, slotIndex)
    }

    function _titleStageSlotPositionAt(slotIndex) {
        return HintLogic.titleStageSlotPositionAt(root, slotIndex)
    }

    function _refreshStageSlots(hint, includeCurrentAnchor, preserveUnassigned) {
        HintLogic.refreshStageSlots(root, hint, includeCurrentAnchor, preserveUnassigned)
    }

    function _settleWorkspaceStageSlots(hint) {
        HintLogic.settleWorkspaceStageSlots(root, hint)
    }

    function _retireWorkspaceStageSlots(hint) {
        return HintLogic.retireWorkspaceStageSlots(root, hint)
    }

    function _cleanupWorkspaceStageSlots(hint) {
        HintLogic.cleanupWorkspaceStageSlots(root, hint)
    }

    function _settleTitleStageSlots(hint) {
        HintLogic.settleTitleStageSlots(root, hint)
    }

    function _retargetHintAnchors(hint, immediate) {
        HintLogic.retargetHintAnchors(root, hint, immediate, _workspaceAnchorSettleTimer, _titleAnchorSettleTimer)
    }

    function _visibleWorkspaceIcons(capsule) {
        return HintLogic.visibleWorkspaceIcons(capsule)
    }

    function _focusedWorkspaceIconIndex(capsule) {
        return HintLogic.focusedWorkspaceIconIndex(capsule)
    }

    function _workspaceMetrics(slotPosition) {
        return HintLogic.workspaceMetrics(root, slotPosition, -1)
    }

    function _workspaceMetricsForSlot(slotPosition, absoluteIndex) {
        return HintLogic.workspaceMetrics(root, slotPosition, absoluteIndex)
    }

    function _titleMetrics(slotPosition) {
        return HintLogic.titleMetrics(root, slotPosition)
    }

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

    Timer {
        id: _clockTimer

        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: root.currentTime = new Date()
    }

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

    Timer {
        id: _workspaceStageCleanupTimer

        repeat: false

        onTriggered: {
            root._cleanupWorkspaceStageSlots(root._hint)
        }
    }

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

    onEventChanged: {
        if (root.measurementMode)
            root._handleHintChange()
    }

    onHintDataChanged: {
        if (root.measurementMode)
            root._handleHintChange()
    }

    Connections {
        target: WindowHintService
        enabled: !root.measurementMode

        function onActiveHintChanged() {
            root._handleHintChange()
        }
    }

    Behavior on _animatedWorkspaceAnchor {
        enabled: root._workspaceAnchorAnimationEnabled

        NumberAnimation {
            id: _workspaceAnchorAnimation

            duration: root._workspaceAnchorDuration
            easing.type: Easing.OutSine
        }
    }

    Behavior on _workspaceLeadingTrim {
        enabled: root._workspaceTrimAnimationEnabled

        NumberAnimation {
            duration: root._workspaceTrimDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on _workspaceTrailingTrim {
        enabled: root._workspaceTrimAnimationEnabled

        NumberAnimation {
            duration: root._workspaceTrimDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on _animatedTitleAnchor {
        enabled: root._titleAnchorAnimationEnabled

        NumberAnimation {
            id: _titleAnchorAnimation

            duration: root._titleAnchorDuration
            easing.type: Easing.OutSine
        }
    }

    QtObject {
        id: _workspaceFocusIndexPair

        property int index: root._workspaceFocusIndex
        property real idx1: index
        property real idx2: index
        property int idx1Duration: root._workspaceFocusLeadDuration
        property int idx2Duration: root._workspaceFocusTrailDuration

        Behavior on idx1 {
            NumberAnimation {
                duration: _workspaceFocusIndexPair.idx1Duration
                easing.type: Easing.OutSine
            }
        }

        Behavior on idx2 {
            NumberAnimation {
                duration: _workspaceFocusIndexPair.idx2Duration
                easing.type: Easing.OutSine
            }
        }
    }

    Component.onCompleted: {
        root._renderHint = root._cloneHint(root._liveHint)
        root._refreshStageSlots(root._renderHint, false, false)
        root._retargetHintAnchors(root._renderHint, true)
        root._syncWorkspaceStageTrim(true)
    }

    Item {
        anchors.fill: parent

        Item {
            id: _contentArea

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Item {
                id: _defaultLayout
                anchors.centerIn: parent
                width: Math.max(root._workspaceStageWidth, root._titleStageWidth)
                height: root._workspaceVisibleStageHeight + root._rowGap + root._titleStageHeight
                visible: root._defaultPresentation

                // Default stack keeps the original two-row arrangement.
                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: root._rowGap

                    // Lower overview lane.
                    Item {
                        width: parent.width
                        height: root._workspaceVisibleStageHeight

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root._workspaceStageWidth
                            height: root._workspaceStageHeight
                            y: -root._workspaceLeadingTrim + root._workspaceSingleSideOffset
                            clip: true

                            Repeater {
                                model: root._persistentStageSlotIndices

                                delegate: IslandParts.IslandWorkspaceStageCapsule {
                                    required property int modelData

                                    host: root
                                    focusIndexPair: _workspaceFocusIndexPair
                                    capsule: root._workspaceStageCapsuleAt(modelData)
                                    absoluteIndex: root._workspaceStageAbsoluteIndexAt(modelData)
                                    slotPosition: root._workspaceStageSlotPositionAt(modelData)
                                    hiddenForMotion: false
                                }
                            }
                        }
                    }

                    // Original title lane.
                    Item {
                        width: parent.width
                        height: root._titleStageHeight

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root._titleStageWidth
                            height: parent.height
                            clip: true

                            Repeater {
                                model: root._persistentStageSlotIndices

                                delegate: IslandParts.IslandTitleStageCapsule {
                                    required property int modelData

                                    host: root
                                    capsule: root._titleStageCapsuleAt(modelData)
                                    slotPosition: root._titleStageSlotPositionAt(modelData)
                                    hiddenForMotion: false
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: _barExpandedLayout
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root._barExpandedDetachedWidth
                height: root._barExpandedCombinedHeight
                visible: root._barExpandedCombinedPresentation

                // Shared backdrop keeps the title and workspace lanes readable as one surface.
                // Shared backdrop keeps the title and workspace lanes moving as one host.
                Item {
                    x: 0
                    y: root._combinedBackdropOffsetY
                    width: parent.width
                    height: parent.height
                    z: -1

                    // Vertical drift keeps the shared backdrop aligned during the title reveal.
                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.anim.moveDuration
                            easing.type: Theme.anim.moveType
                        }
                    }

                    // Title lane keeps the seam square.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: Theme.barHeight
                        radius: 0
                        color: root._stageFill
                    }

                    // Workspace lane keeps the seam square.
                    Rectangle {
                        x: 0
                        y: Theme.barHeight
                        width: parent.width
                        height: root._barExpandedDetachedContentHeight
                        radius: 0
                        color: root._stageFill
                    }

                    // Outer corner caps sit outside the square seam.
                    Canvas {
                        x: -root._barExpandedNotchRadius
                        y: -root._barExpandedNotchRadius
                        width: root._barExpandedNotchRadius
                        height: root._barExpandedNotchRadius
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = root._stageFill
                            ctx.beginPath()
                            ctx.moveTo(0, 0)
                            ctx.lineTo(width, 0)
                            ctx.lineTo(width, height)
                            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
                            ctx.fill()
                        }
                    }

                    // Right corner cap mirrors the same outer arc.
                    Canvas {
                        x: parent.width
                        y: -root._barExpandedNotchRadius
                        width: root._barExpandedNotchRadius
                        height: root._barExpandedNotchRadius
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = root._stageFill
                            ctx.beginPath()
                            ctx.moveTo(0, 0)
                            ctx.lineTo(width, 0)
                            ctx.lineTo(width, height)
                            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
                            ctx.fill()
                        }
                    }

                }

                // Title lane keeps stage-slot animation alive in the widened body.
                Item {
                    width: parent.width
                    height: Theme.barHeight

                    Row {
                        id: _barExpandedCombinedTitleRow

                        anchors.centerIn: parent
                        spacing: root._capsuleGap

                        Repeater {
                            model: root._hint.windows || []

                            // Title capsule wrapper provides enter/exit handoff for the widened host.
                            delegate: Item {
                                required property int index
                                required property var modelData

                                readonly property bool _focused: index === root._hint.currentIndex
                                readonly property string _titleText: modelData ? (modelData.title || "") : ""
                                readonly property string _iconSource: modelData ? (modelData.icon || "") : ""
                                readonly property real _titleMeasuredWidth: _titleMeasurer.paintedWidth
                                readonly property real _iconContentWidth:
                                    _iconSource !== "" ? root._compactIcon + Theme.barWidget.badgePaddingH : 0
                                readonly property real _minimumCapsuleWidth:
                                    root._padH * 2 + Math.max(root._compactIcon, Math.round(Theme.fontSizeSmall * 2.6))
                                readonly property real _maximumCapsuleWidth:
                                    _focused ? root._titlePrimaryWidth : root._titleSideWidth

                                implicitWidth: Math.max(
                                    _minimumCapsuleWidth,
                                    Math.min(
                                        _maximumCapsuleWidth,
                                        root._padH * 2 + _iconContentWidth + _titleMeasuredWidth
                                    )
                                )
                                implicitHeight: root._barExpandedTitleCapsuleHeight
                                width: implicitWidth
                                height: implicitHeight
                                opacity: root.titleCapsuleRevealProgress
                                y: (1 - root.titleCapsuleRevealProgress) * Math.max(6, Theme.barWidget.contentPaddingV * 1.5)
                                scale: 0.96 + root.titleCapsuleRevealProgress * 0.04

                                // Fade the incoming title capsule as the host widens.
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.anim.highlightDuration
                                        easing.type: Theme.anim.highlightType
                                    }
                                }

                                // Lift the capsule into place without changing its width contract.
                                Behavior on y {
                                    NumberAnimation {
                                        duration: Theme.anim.moveDuration
                                        easing.type: Theme.anim.moveType
                                    }
                                }

                                // Restore full scale as the reveal settles.
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.anim.highlightDuration
                                        easing.type: Theme.anim.highlightType
                                    }
                                }

                                // Hidden measurer keeps capsule background width aligned with rendered title content.
                                Text {
                                    id: _titleMeasurer

                                    text: _titleText !== "" ? _titleText : " "
                                    wrapMode: Text.NoWrap
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: _focused
                                    opacity: 0
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: root._mixColor(root._secondaryCapsuleFill, root._primaryCapsuleFill, _focused ? 1 : 0.25)
                                }

                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: root._padH
                                    anchors.rightMargin: root._padH
                                    clip: true

                                    Row {
                                        anchors.fill: parent
                                        spacing: Theme.barWidget.badgePaddingH

                                        Image {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: root._compactIcon
                                            height: width
                                            source: _iconSource
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            visible: source !== ""
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(0, parent.width - (_iconSource !== "" ? root._compactIcon + Theme.barWidget.badgePaddingH : 0))
                                            text: _titleText
                                            color: Colors.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: _focused
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Lower lane reuses the animated workspace coverflow and relocated clock.
                Item {
                    width: parent.width
                    height: root._barExpandedDetachedContentHeight
                    y: Theme.barHeight

                    Column {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: parent.height
                        spacing: root._rowGap

                        // Workspace overview stays in the lower wide rectangle.
                        Item {
                            width: parent.width
                            height: Math.max(0, parent.height - root._rowGap - root._barExpandedDetachedClockHeight)

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: root._workspaceStageWidth
                                height: root._workspaceStageHeight
                                y: -root._workspaceLeadingTrim + root._workspaceSingleSideOffset
                                clip: true

                                Repeater {
                                    model: root._persistentStageSlotIndices

                                    delegate: IslandParts.IslandWorkspaceStageCapsule {
                                        required property int modelData

                                        host: root
                                        focusIndexPair: _workspaceFocusIndexPair
                                        capsule: root._workspaceStageCapsuleAt(modelData)
                                        absoluteIndex: root._workspaceStageAbsoluteIndexAt(modelData)
                                        slotPosition: root._workspaceStageSlotPositionAt(modelData)
                                        hiddenForMotion: false
                                    }
                                }
                            }
                        }

                        // Clock row remains centered below the workspace strip.
                        // Clock handoff keeps the idle clock visible until the relocated copy arrives.
                        Item {
                            visible: root.outgoingClockOpacity > 0.001
                            width: parent.width
                            height: root._barExpandedDetachedClockHeight
                            opacity: root.outgoingClockOpacity
                            y: root.outgoingClockOffsetY

                            // Fade the outgoing clock so the relocated copy can take over cleanly.
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim.highlightDuration
                                    easing.type: Theme.anim.highlightType
                                }
                            }

                            // Keep the outgoing clock on the same motion curve as the title row.
                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.anim.moveDuration
                                    easing.type: Theme.anim.moveType
                                }
                            }

                            IslandParts.IslandIdleClockCard {
                                anchors.centerIn: parent

                                currentTime: root.currentTime
                                hasPendingEvents: SuperIslandService.hasPendingEvents
                                cardHeight: root._barExpandedDetachedClockHeight
                            }
                        }
                    }
                }
            }

            // Inline title-only layout lets the bar host own the expansion width.
            Item {
                id: _barExpandedMainLayout
                anchors.centerIn: parent
                width: root._barExpandedMainWidth
                height: Theme.barHeight
                visible: root._barExpandedMainPresentation

                // Title capsules are tiled in one row in bar-expanded main presentation.
                    Row {
                        id: _barExpandedMainTitleRow

                        anchors.centerIn: parent
                        spacing: root._capsuleGap

                    Repeater {
                        model: root._hint.windows || []

                        // Title capsule wrapper provides enter/exit handoff for the widened host.
                        delegate: Item {
                            required property int index
                            required property var modelData

                            readonly property bool _focused: index === root._hint.currentIndex
                            readonly property string _titleText: modelData ? (modelData.title || "") : ""
                            readonly property string _iconSource: modelData ? (modelData.icon || "") : ""
                            readonly property real _titleMeasuredWidth: _titleMeasurer.paintedWidth
                            readonly property real _iconContentWidth:
                                _iconSource !== "" ? root._compactIcon + Theme.barWidget.badgePaddingH : 0
                            readonly property real _minimumCapsuleWidth:
                                root._padH * 2 + Math.max(root._compactIcon, Math.round(Theme.fontSizeSmall * 2.6))
                            readonly property real _maximumCapsuleWidth:
                                _focused ? root._titlePrimaryWidth : root._titleSideWidth

                            implicitWidth: Math.max(
                                _minimumCapsuleWidth,
                                Math.min(
                                    _maximumCapsuleWidth,
                                    root._padH * 2 + _iconContentWidth + _titleMeasuredWidth
                                )
                            )
                            implicitHeight: root._barExpandedTitleCapsuleHeight
                            width: implicitWidth
                            height: implicitHeight
                            opacity: root.titleCapsuleRevealProgress
                            y: (1 - root.titleCapsuleRevealProgress) * Math.max(6, Theme.barWidget.contentPaddingV * 1.5)
                            scale: 0.96 + root.titleCapsuleRevealProgress * 0.04

                            // Fade the incoming title capsule as the host widens.
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim.highlightDuration
                                    easing.type: Theme.anim.highlightType
                                }
                            }

                            // Lift the capsule into place without changing its width contract.
                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.anim.moveDuration
                                    easing.type: Theme.anim.moveType
                                }
                            }

                            // Restore full scale as the reveal settles.
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.anim.highlightDuration
                                    easing.type: Theme.anim.highlightType
                                }
                            }

                            // Hidden measurer keeps capsule background width aligned with rendered title content.
                            Text {
                                id: _titleMeasurer

                                text: _titleText !== "" ? _titleText : " "
                                wrapMode: Text.NoWrap
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: _focused
                                opacity: 0
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: root._mixColor(root._secondaryCapsuleFill, root._primaryCapsuleFill, _focused ? 1 : 0.25)
                            }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: root._padH
                                anchors.rightMargin: root._padH
                                clip: true

                                Row {
                                    anchors.fill: parent
                                    spacing: Theme.barWidget.badgePaddingH

                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: root._compactIcon
                                        height: width
                                        source: _iconSource
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        visible: source !== ""
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(0, parent.width - (_iconSource !== "" ? root._compactIcon + Theme.barWidget.badgePaddingH : 0))
                                        text: _titleText
                                        color: Colors.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: _focused
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

                Item {
                    id: _barExpandedDetachedLayout
                    anchors.top: parent.top
                    anchors.topMargin: root._padV + root._stagePadV
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root._barExpandedDetachedWidth
                    height: root._barExpandedDetachedContentHeight
                    visible: root._barExpandedDetachedPresentation

                    // Inner column keeps the workspace stage and relocated clock centered.
                    Column {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: parent.height
                        spacing: root._rowGap

                    Item {
                        width: parent.width
                        height: Math.max(0, parent.height - root._rowGap - root._barExpandedDetachedClockHeight)

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root._workspaceStageWidth
                            height: root._workspaceStageHeight
                            y: -root._workspaceLeadingTrim + root._workspaceSingleSideOffset
                            clip: true

                            Repeater {
                                model: root._persistentStageSlotIndices

                                delegate: IslandParts.IslandWorkspaceStageCapsule {
                                    required property int modelData

                                    host: root
                                    focusIndexPair: _workspaceFocusIndexPair
                                    capsule: root._workspaceStageCapsuleAt(modelData)
                                    absoluteIndex: root._workspaceStageAbsoluteIndexAt(modelData)
                                    slotPosition: root._workspaceStageSlotPositionAt(modelData)
                                    hiddenForMotion: false
                                }
                            }
                        }
                    }

                    // Relocated clock fades into the detached lane instead of being hard-swapped.
                        Item {
                            width: parent.width
                            height: root._barExpandedDetachedClockHeight
                            opacity: root.relocatedClockOpacity
                            y: root.relocatedClockOffsetY

                            // Fade the relocated clock in as it reaches the lower lane.
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim.highlightDuration
                                    easing.type: Theme.anim.highlightType
                                }
                            }

                            // Match the relocation movement to the shared reveal timing.
                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.anim.moveDuration
                                    easing.type: Theme.anim.moveType
                            }
                        }

                        IslandParts.IslandIdleClockCard {
                            anchors.centerIn: parent

                            currentTime: root.currentTime
                            hasPendingEvents: SuperIslandService.hasPendingEvents
                            cardHeight: root._barExpandedDetachedClockHeight
                        }
                    }
                }
            }
        }
    }
}
