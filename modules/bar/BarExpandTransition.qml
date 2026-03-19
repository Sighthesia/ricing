import QtQuick
import qs.config

// Shared geometry timeline for bar widgets that need a preload, overshoot, and settle phase.
Item {
    id: root

    implicitWidth: 0
    implicitHeight: 0
    visible: false

    required property real collapsedWidth
    required property real expandedWidth
    required property real collapsedHeight
    required property real expandedHeight

    property bool expanded: false
    property bool animateWidth: true
    property bool animateHeight: true
    property bool pulseEnabled: Theme.anim.barExpandPulseEnabled

    readonly property real animatedWidth: _animatedWidth
    readonly property real animatedHeight: _animatedHeight
    readonly property real pulseOpacity: _pulseOpacity
    readonly property real pulseScale: _pulseScale
    readonly property bool running: _timeline.running

    property bool _ready: false
    property bool _suppressExpandedTimeline: false
    property bool _retargetPending: false
    property bool _retargetActiveForCurrentRun: false
    property int _currentPreloadDuration: Theme.anim.barExpandPreloadDuration
    property real _animatedWidth: collapsedWidth
    property real _animatedHeight: collapsedHeight
    property real _pulseOpacity: 0
    property real _pulseScale: 1
    property real _phase1Width: collapsedWidth
    property real _phase2Width: collapsedWidth
    property real _phase3Width: collapsedWidth
    property real _phase1Height: collapsedHeight
    property real _phase2Height: collapsedHeight
    property real _phase3Height: collapsedHeight
    property real _phase1PulseOpacity: 0
    property real _phase2PulseOpacity: 0
    property real _phase3PulseOpacity: 0
    property real _phase1PulseScale: 1
    property real _phase2PulseScale: 1
    property real _phase3PulseScale: 1

    SequentialAnimation {
        id: _timeline

        onFinished: {
            if (root._retargetPending)
                _retargetTimer.restart()
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_animatedWidth"
                to: root._phase1Width
                duration: root._currentPreloadDuration
                easing.type: Theme.anim.moveType
            }

            NumberAnimation {
                target: root
                property: "_animatedHeight"
                to: root._phase1Height
                duration: root._currentPreloadDuration
                easing.type: Theme.anim.moveType
            }

            NumberAnimation {
                target: root
                property: "_pulseOpacity"
                to: root._phase1PulseOpacity
                duration: root._currentPreloadDuration
                easing.type: Theme.anim.highlightType
            }

            NumberAnimation {
                target: root
                property: "_pulseScale"
                to: root._phase1PulseScale
                duration: root._currentPreloadDuration
                easing.type: Theme.anim.moveType
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_animatedWidth"
                to: root._phase2Width
                duration: Theme.anim.barExpandOvershootDuration
                easing.type: root._retargetActiveForCurrentRun
                    ? Theme.anim.pulseSpringType
                    : Theme.anim.springType
                easing.overshoot: root._retargetActiveForCurrentRun
                    ? Theme.anim.pulseSpringOvershoot
                    : Theme.anim.springOvershoot
            }

            NumberAnimation {
                target: root
                property: "_animatedHeight"
                to: root._phase2Height
                duration: Theme.anim.barExpandOvershootDuration
                easing.type: root._retargetActiveForCurrentRun
                    ? Theme.anim.pulseSpringType
                    : Theme.anim.springType
                easing.overshoot: root._retargetActiveForCurrentRun
                    ? Theme.anim.pulseSpringOvershoot
                    : Theme.anim.springOvershoot
            }

            NumberAnimation {
                target: root
                property: "_pulseOpacity"
                to: root._phase2PulseOpacity
                duration: Theme.anim.barExpandOvershootDuration
                easing.type: Theme.anim.highlightType
            }

            NumberAnimation {
                target: root
                property: "_pulseScale"
                to: root._phase2PulseScale
                duration: Theme.anim.barExpandOvershootDuration
                easing.type: Theme.anim.springType
                easing.overshoot: Theme.anim.pulseSpringOvershoot
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "_animatedWidth"
                to: root._phase3Width
                duration: Theme.anim.barExpandSettleDuration
                easing.type: Theme.anim.moveType
            }

            NumberAnimation {
                target: root
                property: "_animatedHeight"
                to: root._phase3Height
                duration: Theme.anim.barExpandSettleDuration
                easing.type: Theme.anim.moveType
            }

            NumberAnimation {
                target: root
                property: "_pulseOpacity"
                to: root._phase3PulseOpacity
                duration: Theme.anim.barExpandSettleDuration
                easing.type: Theme.anim.highlightType
            }

            NumberAnimation {
                target: root
                property: "_pulseScale"
                to: root._phase3PulseScale
                duration: Theme.anim.barExpandSettleDuration
                easing.type: Theme.anim.pulseSpringType
                easing.overshoot: Theme.anim.pulseSpringOvershoot
            }
        }
    }

    function _applyPhaseTargets(isExpanded, retargetActive) {
        const expandPreloadWidth = collapsedWidth * (1 - Theme.anim.barExpandExpandPreloadRatio)
        const expandPreloadHeight = collapsedHeight * (1 - Theme.anim.barExpandExpandPreloadRatio)
        const expandOvershootWidth = expandedWidth * (1 + Theme.anim.barExpandExpandOvershootRatio)
        const expandOvershootHeight = expandedHeight * (1 + Theme.anim.barExpandExpandOvershootRatio)
        const collapsePreloadWidth = expandedWidth * (1 + Theme.anim.barExpandCollapsePreloadRatio)
        const collapsePreloadHeight = expandedHeight * (1 + Theme.anim.barExpandCollapsePreloadRatio)
        const collapseOvershootWidth = collapsedWidth * (1 - Theme.anim.barExpandCollapseOvershootRatio)
        const collapseOvershootHeight = collapsedHeight * (1 - Theme.anim.barExpandCollapseOvershootRatio)
        const widthTarget = isExpanded ? expandedWidth : collapsedWidth
        const heightTarget = isExpanded ? expandedHeight : collapsedHeight
        const retargetWidthOvershoot = widthTarget
            + (widthTarget - _animatedWidth)
              * (isExpanded
                  ? Theme.anim.barExpandExpandOvershootRatio
                  : Theme.anim.barExpandCollapseOvershootRatio)
        const retargetHeightOvershoot = heightTarget
            + (heightTarget - _animatedHeight)
              * (isExpanded
                  ? Theme.anim.barExpandExpandOvershootRatio
                  : Theme.anim.barExpandCollapseOvershootRatio)

        _phase1Width = retargetActive
            ? _animatedWidth
            : (animateWidth ? (isExpanded ? expandPreloadWidth : collapsePreloadWidth) : (isExpanded ? expandedWidth : collapsedWidth))
        _phase2Width = animateWidth
            ? (retargetActive
                ? retargetWidthOvershoot
                : (isExpanded ? expandOvershootWidth : collapseOvershootWidth))
            : widthTarget
        _phase3Width = isExpanded ? expandedWidth : collapsedWidth

        _phase1Height = retargetActive
            ? _animatedHeight
            : (animateHeight ? (isExpanded ? expandPreloadHeight : collapsePreloadHeight) : (isExpanded ? expandedHeight : collapsedHeight))
        _phase2Height = animateHeight
            ? (retargetActive
                ? retargetHeightOvershoot
                : (isExpanded ? expandOvershootHeight : collapseOvershootHeight))
            : heightTarget
        _phase3Height = isExpanded ? expandedHeight : collapsedHeight

        _currentPreloadDuration = retargetActive ? 1 : Theme.anim.barExpandPreloadDuration

        if (isExpanded) {
            _phase1PulseOpacity = retargetActive
                ? _pulseOpacity
                : (pulseEnabled ? Theme.anim.barExpandExpandPulsePreloadOpacity : 0)
            _phase2PulseOpacity = pulseEnabled ? Theme.anim.barExpandExpandPulseOvershootOpacity : 0
            _phase3PulseOpacity = Theme.anim.barExpandPulseSettleOpacity
            _phase1PulseScale = retargetActive
                ? _pulseScale
                : (pulseEnabled ? Theme.anim.barExpandExpandPulsePreloadScale : 1)
            _phase2PulseScale = pulseEnabled ? Theme.anim.barExpandExpandPulseOvershootScale : 1
            _phase3PulseScale = Theme.anim.barExpandPulseSettleScale
            return
        }

        _phase1PulseOpacity = retargetActive
            ? _pulseOpacity
            : (pulseEnabled ? Theme.anim.barExpandCollapsePulsePreloadOpacity : 0)
        _phase2PulseOpacity = pulseEnabled ? Theme.anim.barExpandCollapsePulseOvershootOpacity : 0
        _phase3PulseOpacity = Theme.anim.barExpandPulseSettleOpacity
        _phase1PulseScale = retargetActive
            ? _pulseScale
            : (pulseEnabled ? Theme.anim.barExpandCollapsePulsePreloadScale : 1)
        _phase2PulseScale = pulseEnabled ? Theme.anim.barExpandCollapsePulseOvershootScale : 1
        _phase3PulseScale = Theme.anim.barExpandPulseSettleScale
    }

    function _startTimeline(retargetActive) {
        if (!_ready || _suppressExpandedTimeline)
            return

        _retargetPending = false
        _retargetActiveForCurrentRun = !!retargetActive
        _applyPhaseTargets(expanded, !!retargetActive)
        _timeline.restart()
    }

    function _syncToCurrentTruth() {
        _timeline.stop()
        _retargetPending = false
        _retargetActiveForCurrentRun = false
        _currentPreloadDuration = Theme.anim.barExpandPreloadDuration
        _animatedWidth = expanded ? expandedWidth : collapsedWidth
        _animatedHeight = expanded ? expandedHeight : collapsedHeight
        _pulseOpacity = 0
        _pulseScale = 1
    }

    function _targetWidth() {
        return expanded ? expandedWidth : collapsedWidth
    }

    function _targetHeight() {
        return expanded ? expandedHeight : collapsedHeight
    }

    function _targetDeltaExceedsThreshold(currentValue, targetValue) {
        return Math.abs(currentValue - targetValue) > 0.5
    }

    function _handleLiveGeometryChange() {
        if (!_ready)
            return

        const widthChanged = _targetDeltaExceedsThreshold(_animatedWidth, _targetWidth())
        const heightChanged = _targetDeltaExceedsThreshold(_animatedHeight, _targetHeight())
        const hasGeometryDelta = widthChanged || heightChanged
        const canAnimateDelta = (widthChanged && animateWidth) || (heightChanged && animateHeight)

        if (!_timeline.running) {
            if (!hasGeometryDelta || !canAnimateDelta) {
                _syncToCurrentTruth()
                return
            }

            _startTimeline(true)
            return
        }

        _retargetPending = true
        _retargetTimer.restart()
    }

    function _handleTargetChange(targetsExpandedState) {
        if (targetsExpandedState !== expanded)
            return

        _handleLiveGeometryChange()
    }

    function snapToExpanded() {
        _suppressExpandedTimeline = true
        expanded = true
        _suppressExpandedTimeline = false
        _syncToCurrentTruth()
    }

    function snapToCollapsed() {
        _suppressExpandedTimeline = true
        expanded = false
        _suppressExpandedTimeline = false
        _syncToCurrentTruth()
    }

    onExpandedChanged: _startTimeline(false)
    onCollapsedWidthChanged: _handleTargetChange(false)
    onExpandedWidthChanged: _handleTargetChange(true)
    onCollapsedHeightChanged: _handleTargetChange(false)
    onExpandedHeightChanged: _handleTargetChange(true)
    onAnimateWidthChanged: _handleLiveGeometryChange()
    onAnimateHeightChanged: _handleLiveGeometryChange()
    onPulseEnabledChanged: {
        if (!_ready || _timeline.running)
            return

        _syncToCurrentTruth()
    }

    Component.onCompleted: {
        _ready = true
        _syncToCurrentTruth()
    }

    Timer {
        id: _retargetTimer

        interval: 0
        repeat: false
        onTriggered: {
            if (!root._ready)
                return

            if (_timeline.running) {
                root._startTimeline(true)
                return
            }

            root._syncToCurrentTruth()
        }
    }
}
