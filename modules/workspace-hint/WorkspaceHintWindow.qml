import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services
import "." as WorkspaceHint
import "WorkspaceHintStage.js" as Stage
import "WorkspaceHintMotion.js" as Motion

// OSD popup: render the workspace hint as a slot-based anchor stage.
Variants {
    id: root

    model: Quickshell.screens

    // Keep one independent workspace-hint overlay per screen.
    PanelWindow {
        id: hintWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region { item: hintHitRegion }
        visible: hintWindow._windowVisible

        property bool _windowVisible: false
        property var testHintHeld: null
        property var testHintData: null
        property bool _hintActive: testHintHeld !== null ? testHintHeld : Services.WindowHintService.hintVisible
        property var _hintData: testHintData !== null ? testHintData : Services.WindowHintService.activeHint
        property var _renderHint: null
        property var _transitionSourceHint: null
        property var _workspaceStageSlots: Motion.emptyStageSlots(_persistentStageSlotIndices, "workspace-slot")
        property real _animatedWorkspaceAnchor: -1
        property real _workspaceAnchorTarget: -1
        property int _workspaceAnchorDuration: _workspaceAnchorBaseDuration
        property bool _workspaceAnchorAnimationEnabled: true
        property bool _workspaceSettlePending: false
        property real _stageTopProgress: 0
        property real _stageMiddleProgress: 0
        property real _stageBottomProgress: 0

        readonly property int _activeWorkspacePosition: _hintData.activeWorkspacePosition
        readonly property var _persistentStageSlotIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        readonly property real _overflowSlotPosition: 1.18
        readonly property int _workspaceSideWidth: 90
        property int _workspacePrimaryWidth: _workspacePrimaryWidthForHint(_renderHint || _hintData)
        readonly property int _workspaceSideHeight: 28
        readonly property int _workspacePrimaryHeight: 40
        readonly property int _workspaceColumnGap: 8
        readonly property int _workspaceStageWidth: _workspacePrimaryWidth
        readonly property int _workspaceStageHeight: _workspaceSideHeight * 2 + _workspacePrimaryHeight + _workspaceColumnGap * 2
        readonly property real _workspaceStageTargetY: Services.BarLayoutService.barHeight + 16
        readonly property int _workspaceAnchorBaseDuration: Math.max(150, Services.Motion.number.surfaceDuration)
        property int _workspaceCapsuleOpacityDuration: Math.max(90, Services.Motion.number.surfaceDuration)
        readonly property int _anchorDurationStep: 24
        readonly property int _anchorMaximumDuration: 240

        function _workspaceMetricsForSlot(slotPosition, absoluteIndex) {
            return Motion.workspaceMetrics(hintWindow, slotPosition, absoluteIndex)
        }

        function _workspacePrimaryWidthForAbsoluteIndex(absoluteIndex) {
            const currentHint = _renderHint || _hintData
            const currentWidth = _workspacePrimaryWidthForHint(currentHint)

            if (_workspaceSettlePending && _transitionSourceHint) {
                const previousPosition = _transitionSourceHint.activeWorkspacePosition !== undefined
                    ? _transitionSourceHint.activeWorkspacePosition
                    : -1
                const currentPosition = currentHint && currentHint.activeWorkspacePosition !== undefined
                    ? currentHint.activeWorkspacePosition
                    : -1

                if (absoluteIndex === previousPosition && absoluteIndex !== currentPosition)
                    return _workspacePrimaryWidthForHint(_transitionSourceHint)
                if (absoluteIndex === currentPosition)
                    return currentWidth
            }

            return currentWidth
        }

        function _workspacePrimaryWidthForHint(hint) {
            const safeHint = hint || {}
            const windows = safeHint.windows || []
            let width = 24

            if (safeHint.workspaceIndex !== undefined && safeHint.workspaceIndex > 0)
                width += 20

            if (windows.length === 0)
                return 132

            for (let index = 0; index < windows.length; index++) {
                const windowData = windows[index] || {}
                const title = windowData.title || ""
                const titleWidth = Math.min(140, Math.max(24, title.length * 7))
                const iconWidth = windowData.icon ? 19 : 0
                const cardWidth = Math.max(100, titleWidth + iconWidth + 24)
                width += cardWidth
                if (index < windows.length - 1)
                    width += 6
            }

            return Math.max(132, Math.min(520, width))
        }

        function _refreshWorkspaceStage(hint, includeCurrentAnchor, preserveUnassigned) {
            Motion.refreshStageSlots(hintWindow, hint, includeCurrentAnchor, preserveUnassigned, Stage)
        }

        function _settleWorkspaceStage(hint) {
            Motion.settleWorkspaceStageSlots(hintWindow, hint, Stage)
        }

        function _stageRevealForSlot(slotPosition) {
            if (slotPosition <= -0.5)
                return _stageTopProgress
            if (slotPosition < 0.5)
                return _stageMiddleProgress
            return _stageBottomProgress
        }

        function _setStageRevealProgress(top, middle, bottom) {
            _stageTopProgress = top
            _stageMiddleProgress = middle
            _stageBottomProgress = bottom
        }

        on_HintActiveChanged: {
            if (_hintActive) {
                _hideTimer.stop()
                _windowVisible = true
                _exitTopTimer.stop()
                _exitMiddleTimer.stop()
                _exitBottomTimer.stop()
                _setStageRevealProgress(0, 0, 0)
                _enterTopTimer.restart()
                _enterMiddleTimer.restart()
                _enterBottomTimer.restart()
                Motion.handleHintChange(hintWindow, _hintData, _workspaceAnchorSettleTimer, Stage)
                return
            }

            _enterTopTimer.stop()
            _enterMiddleTimer.stop()
            _enterBottomTimer.stop()
            _exitBottomTimer.restart()
            _exitMiddleTimer.restart()
            _exitTopTimer.restart()
            _hideTimer.restart()
        }

        on_HintDataChanged: {
            if (!_hintActive)
                return

            if (!_windowVisible)
                _windowVisible = true

            Motion.handleHintChange(hintWindow, _hintData, _workspaceAnchorSettleTimer, Stage)
        }

        // Hide the window only after the release grace period finishes.
        Timer {
            id: _hideTimer
            interval: 380
            onTriggered: hintWindow._windowVisible = false
        }

        // Stagger the top capsule into view from y = 0.
        Timer {
            id: _enterTopTimer
            interval: 20
            onTriggered: hintWindow._stageTopProgress = 1
        }

        // Stagger the center capsule into view after the top slot.
        Timer {
            id: _enterMiddleTimer
            interval: 70
            onTriggered: hintWindow._stageMiddleProgress = 1
        }

        // Stagger the bottom capsule into view last.
        Timer {
            id: _enterBottomTimer
            interval: 100
            onTriggered: hintWindow._stageBottomProgress = 1
        }

        // Reverse the bottom capsule back toward y = 0 first.
        Timer {
            id: _exitBottomTimer
            interval: 20
            onTriggered: hintWindow._stageBottomProgress = 0
        }

        // Reverse the center capsule after the bottom slot.
        Timer {
            id: _exitMiddleTimer
            interval: 50
            onTriggered: hintWindow._stageMiddleProgress = 0
        }

        // Reverse the top capsule last to mirror the old staging.
        Timer {
            id: _exitTopTimer
            interval: 80
            onTriggered: hintWindow._stageTopProgress = 0
        }

        // Wait for the workspace anchor motion to settle before cleaning stage slots.
        Timer {
            id: _workspaceAnchorSettleTimer
            repeat: false
            onTriggered: {
                if (!hintWindow._workspaceSettlePending)
                    return
                if (Math.abs(hintWindow._animatedWorkspaceAnchor - hintWindow._workspaceAnchorTarget) > 0.001) {
                    interval = 16
                    restart()
                    return
                }

                hintWindow._workspaceSettlePending = false
                hintWindow._settleWorkspaceStage(hintWindow._renderHint)
            }
        }

        // Keep workspace switching on a smooth anchor tween like DymicShell.
        Behavior on _animatedWorkspaceAnchor {
            enabled: hintWindow._workspaceAnchorAnimationEnabled

            NumberAnimation {
                duration: hintWindow._workspaceAnchorDuration
                easing.type: Easing.OutSine
            }
        }

        // Animate the top staged reveal progress.
        Behavior on _stageTopProgress {
            NumberAnimation {
                duration: Services.Motion.number.surfaceDuration
                easing.type: Easing.OutCubic
            }
        }

        // Animate the center staged reveal progress.
        Behavior on _stageMiddleProgress {
            NumberAnimation {
                duration: Services.Motion.number.surfaceDuration
                easing.type: Easing.OutCubic
            }
        }

        // Animate the bottom staged reveal progress.
        Behavior on _stageBottomProgress {
            NumberAnimation {
                duration: Services.Motion.number.surfaceDuration
                easing.type: Easing.OutCubic
            }
        }

        // Own the centered stage and hit region inside the transparent overlay.
        Item {
            id: hintContainer
            anchors.fill: parent
            readonly property real _wsTargetY: hintWindow._workspaceStageTargetY

            // Restrict input to the visible stage capsules.
            Item {
                id: hintHitRegion

                readonly property real _left: {
                    var min = workspaceStage.x + workspaceStage.width
                    for (var i = 0; i < stageRepeater.count; i++) {
                        var item = stageRepeater.itemAt(i)
                        if (item && item.visible) min = Math.min(min, workspaceStage.x + item.x)
                    }
                    return min
                }
                readonly property real _top: {
                    var min = hintContainer.height
                    for (var i = 0; i < stageRepeater.count; i++) {
                        var item = stageRepeater.itemAt(i)
                        if (item && item.visible) min = Math.min(min, workspaceStage.y + item.visibleY)
                    }
                    return min
                }
                readonly property real _right: {
                    var max = workspaceStage.x
                    for (var i = 0; i < stageRepeater.count; i++) {
                        var item = stageRepeater.itemAt(i)
                        if (item && item.visible) max = Math.max(max, workspaceStage.x + item.x + item.width)
                    }
                    return max
                }
                readonly property real _bottom: {
                    var max = workspaceStage.y
                    for (var i = 0; i < stageRepeater.count; i++) {
                        var item = stageRepeater.itemAt(i)
                        if (item && item.visible) max = Math.max(max, workspaceStage.y + item.visibleY + item.height)
                    }
                    return max
                }

                x: _left < hintContainer.width ? _left : 0
                y: _top < hintContainer.height ? _top : 0
                width: Math.max(0, _right - x)
                height: Math.max(0, _bottom - y)
            }

            // Center the slot stage below the bar edge.
            Item {
                id: workspaceStage

                x: (hintContainer.width - width) / 2
                y: hintContainer._wsTargetY
                width: hintWindow._workspaceStageWidth
                height: hintWindow._workspaceStageHeight
                clip: false

                // Render the persistent workspace stage slots.
                Repeater {
                    id: stageRepeater

                    model: hintWindow._persistentStageSlotIndices.length

                    delegate: WorkspaceHint.WorkspaceHintCapsule {
                        required property int index

                        readonly property var _slotData:
                            index >= 0 && index < hintWindow._workspaceStageSlots.length
                                ? hintWindow._workspaceStageSlots[index]
                                : null

                        host: hintWindow
                        capsule: _slotData ? _slotData.capsule : null
                        absoluteIndex: _slotData ? _slotData.absoluteIndex : -1
                        slotPosition: Stage.workspaceStageSlotPositionAt(hintWindow, index)
                    }
                }
            }
        }
    }
}
