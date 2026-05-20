import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services
import "."
import "WorkspaceHintViewportModel.js" as ViewportModel

// OSD popup: a compact stack of workspace capsules drops from the top edge.
Variants {
    id: root

    model: Quickshell.screens

    // Per-screen workspace hint overlay
    PanelWindow {
        id: hintWindow

        required property var modelData

        // Hold the per-window viewport transition state close to the consumer scope.
        WorkspaceHintViewportState {
            id: viewportState
        }

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        // Below bar/dockzone background layer
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Restrict input to visible capsule area so clicks pass through to windows behind.
        mask: Region { item: hintHitRegion }

        // Decouple window visibility from hint state to allow exit animation.
        // Window stays visible during exit, then hides after animation completes.
        visible: hintWindow._windowVisible

        property bool _windowVisible: false

        // Test override: non-null means "use this value instead of service".
        property var testHintHeld: null

        // Test override: non-null means "use this data instead of service".
        property var testHintData: null

        // Hint active state: testHintHeld overrides when non-null.
        property bool _hintActive: testHintHeld !== null ? testHintHeld : Services.WindowHintService.hintVisible

        // Hint data: testHintData overrides when non-null.
        property var _hintData: testHintData !== null ? testHintData : Services.WindowHintService.activeHint

        // Count of capsules currently rendered by the Repeater.
        property int renderedCapsuleCount: _hintData.workspaces ? _hintData.workspaces.length : 0

        readonly property int _activeWorkspacePosition: _hintData.activeWorkspacePosition

        // Track the last revision consumed by the viewport queue.
        property int _lastConsumedTransitionRevision: 0
        property int _previousVisualWorkspacePosition: -1
        property var _previousVisualWindows: []
        property string _previousVisualWindowTitle: ""
        property string _previousVisualWindowIcon: ""

        // Restore the original top-down staged entry for the first three capsules.
        property bool _stageTop: false
        property bool _stageMiddle: false
        property bool _stageBottom: false

        function _advanceViewportStepNow() {
            if (viewportState.pendingWorkspaceSteps.length === 0)
                return

            viewportState.advancePendingWorkspaceStep()
            if (viewportState.pendingWorkspaceSteps.length > 0)
                _stepAdvanceTimer.restart()
        }

        // Viewport-level enter/exit: show immediately on hold, fade out after delay on release.
        on_HintActiveChanged: {
            if (_hintActive) {
                // Enter: show window and sync viewport focus.
                _hideTimer.stop()
                _windowVisible = true
                _stageTop = false
                _stageMiddle = false
                _stageBottom = false
                _enterTopTimer.restart()
                _enterMiddleTimer.restart()
                _enterBottomTimer.restart()

                // Sync viewport focus once when the hint first becomes visible.
                viewportState.visualFocusPosition = _activeWorkspacePosition
                viewportState.animatedVisualFocusPosition = _activeWorkspacePosition
                viewportState.settledWorkspacePosition = _activeWorkspacePosition
                viewportState.targetWorkspacePosition = _activeWorkspacePosition
                viewportState.pendingWorkspaceSteps = []
                _lastConsumedTransitionRevision = _hintData.workspaceTransitionRevision || 0
                _previousVisualWorkspacePosition = _activeWorkspacePosition
                _previousVisualWindows = _hintData.windows || []
                _previousVisualWindowTitle = _hintData.currentWindowTitle || ""
                _previousVisualWindowIcon = _hintData.currentWindowIcon || ""
            } else {
                // Release: start hide timer. Window stays visible until timer fires.
                _hideTimer.restart()
            }
        }

        // Restore the top capsule staged entry from y = 0.
        Timer {
            id: _enterTopTimer
            interval: 20
            onTriggered: hintWindow._stageTop = true
        }

        // Restore the middle capsule staged entry from y = 0.
        Timer {
            id: _enterMiddleTimer
            interval: 70
            onTriggered: hintWindow._stageMiddle = true
        }

        // Restore the bottom capsule staged entry from y = 0.
        Timer {
            id: _enterBottomTimer
            interval: 100
            onTriggered: hintWindow._stageBottom = true
        }

        on_ActiveWorkspacePositionChanged: {
            if (_hintActive && !_windowVisible)
                _windowVisible = true

            if (!_hintActive)
                return

            if (viewportState.pendingWorkspaceSteps.length === 0
                    && viewportState.targetWorkspacePosition === viewportState.settledWorkspacePosition
                    && viewportState.settledWorkspacePosition === _activeWorkspacePosition) {
                viewportState.visualFocusPosition = _activeWorkspacePosition
            }
        }

        on_HintDataChanged: {
            const nextRevision = _hintData && _hintData.workspaceTransitionRevision
                ? _hintData.workspaceTransitionRevision
                : 0

            if (!_hintActive)
                return
            if (nextRevision <= _lastConsumedTransitionRevision)
                return

            viewportState.enqueueWorkspaceTransition(
                _hintData.previousActiveWorkspacePosition,
                _hintData.activeWorkspacePosition
            )
            _previousVisualWorkspacePosition = _hintData.previousActiveWorkspacePosition
            _previousVisualWindows = _hintData.windows || []
            _previousVisualWindowTitle = _hintData.currentWindowTitle || ""
            _previousVisualWindowIcon = _hintData.currentWindowIcon || ""
            _lastConsumedTransitionRevision = nextRevision

            if (viewportState.targetWorkspacePosition === viewportState.settledWorkspacePosition)
                _advanceViewportStepNow()
        }

        // Hide window after release delay completes.
        Timer {
            id: _hideTimer
            interval: 380
            onTriggered: hintWindow._windowVisible = false
        }

        // Advance the next queued workspace hop after the current motion settles.
        Timer {
            id: _stepAdvanceTimer
            interval: Services.Motion.number.surfaceDuration
            repeat: false
            onTriggered: {
                hintWindow._advanceViewportStepNow()
            }
        }

        // Full-screen transparent container
        Item {
            id: hintContainer
            anchors.fill: parent

            // Keep the stacked hint below the bar while it drops from the top edge.
            readonly property real _wsTargetY: Services.BarLayoutService.barHeight + 16

            // Bound input to the stacked workspace hint surface.
            Item {
                id: hintHitRegion
                readonly property real _left: {
                    var min = hintContainer.width
                    for (var i = 0; i < capsuleRepeater.count; i++) {
                        var item = capsuleRepeater.itemAt(i)
                        if (item && item.visible) min = Math.min(min, item.x)
                    }
                    return min
                }
                readonly property real _top: {
                    var min = hintContainer.height
                    for (var i = 0; i < capsuleRepeater.count; i++) {
                        var item = capsuleRepeater.itemAt(i)
                        if (item && item.visible) min = Math.min(min, item.visibleY)
                    }
                    return min
                }
                readonly property real _right: {
                    var max = 0
                    for (var i = 0; i < capsuleRepeater.count; i++) {
                        var item = capsuleRepeater.itemAt(i)
                        if (item && item.visible) max = Math.max(max, item.x + item.width)
                    }
                    return max
                }
                readonly property real _bottom: {
                    var max = 0
                    for (var i = 0; i < capsuleRepeater.count; i++) {
                        var item = capsuleRepeater.itemAt(i)
                        if (item && item.visible) max = Math.max(max, item.visibleY + item.height)
                    }
                    return max
                }

                x: _left < hintContainer.width ? _left : 0
                y: _top < hintContainer.height ? _top : 0
                width: Math.max(0, _right - x)
                height: Math.max(0, _bottom - y)
            }

            // Render capsules dynamically from the workspace list.
            Repeater {
                id: capsuleRepeater

                model: hintWindow._hintData.workspaces || []

                // Delegate: one WorkspaceHintCapsule per workspace entry.
                WorkspaceHintCapsule {
                    id: capsule

                    required property var modelData
                    required property int index

                    readonly property real _relativeOffset:
                        ViewportModel.relativeOffset(index, viewportState.animatedVisualFocusPosition)
                    readonly property bool _staggerVisible:
                        ViewportModel.staggerVisibilityForIndex(
                            index,
                            hintWindow._stageTop,
                            hintWindow._stageMiddle,
                            hintWindow._stageBottom
                        )
                    readonly property bool _usesPreviousVisualContent:
                        index === hintWindow._previousVisualWorkspacePosition
                        && index !== hintWindow._activeWorkspacePosition
                        && focusProgress > 0

                    visible: hintWindow._windowVisible && _staggerVisible
                    workspacePosition: index
                    workspaceIndex: modelData.workspaceIndex
                    relativeOffset: _relativeOffset
                    focusProgress: ViewportModel.focusProgressForOffset(_relativeOffset)
                    cameraDistance: Math.abs(_relativeOffset)
                    active: index === hintWindow._activeWorkspacePosition
                    useFocusedGeometry: ViewportModel.useFocusedWidthForCapsule(
                        index === hintWindow._activeWorkspacePosition,
                        _usesPreviousVisualContent,
                        focusProgress
                    )
                    icons: modelData.icons || []
                    windows: index === hintWindow._activeWorkspacePosition
                        ? (_hintData.windows || [])
                        : (_usesPreviousVisualContent ? (hintWindow._previousVisualWindows || []) : [])
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: ViewportModel.shouldExpandCapsule(
                        _staggerVisible,
                        hintWindow._hintActive
                    )
                    baseY: {
                        var y = hintContainer._wsTargetY
                        for (var i = 0; i < capsule.index; i++) {
                            var prev = capsuleRepeater.itemAt(i)
                            if (prev) y += prev.expandedHeightHint + 8
                        }
                        return y
                    }
                    currentWindowTitle: _usesPreviousVisualContent
                        ? hintWindow._previousVisualWindowTitle
                        : hintWindow._hintData.currentWindowTitle
                    currentWindowIcon: _usesPreviousVisualContent
                        ? hintWindow._previousVisualWindowIcon
                        : hintWindow._hintData.currentWindowIcon
                }
            }
        }
    }
}
