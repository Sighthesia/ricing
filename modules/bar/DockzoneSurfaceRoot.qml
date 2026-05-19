import "."
import "DockzoneSurfaceModel.js" as Model
import QtQuick
import "../../services" as Services

// Surface-local owner for a dockzone path — first validated on center.
// Owns semantic state input and animated canonical progress drivers.
Item {
    id: root

    // High-level semantic inputs from the section owner.
    required property string section
    required property string screenName
    property string surfaceState: "attached"
    property bool hoverIntent: false
    required property real surfaceHeight
    required property real contentWidth
    required property real contentHeight

    // Owner-local animated canonical progress drivers.
    // Initialized from the initial surfaceState so stable "attached" starts
    // at full progress without an unwanted entrance animation.
    property real _visibilityProgress: 1
    property real _stateTransitionProgress: 1
    property real _detachProgress: 0
    property real _morphProgress: 0
    property real _hoverProgress: 0

    // Map a target semantic state to canonical progress targets.
    function _targetsForState(state) {
        if (state === "hidden" || state === "exiting")
            return {v: 0, t: 0, d: 0, m: 0};
        if (state === "floating")
            return {v: 1, t: 1, d: 1, m: 1};
        // "entering" and "attached" both target full visibility.
        return {v: 1, t: 1, d: 0, m: 0};
    }

    function _targetHoverProgress() {
        return hoverIntent ? 1 : 0;
    }

    // Trigger a transition to the given semantic state.
    function transitionTo(state) {
        var targets = _targetsForState(state);
        _visAnim.stop();
        _transAnim.stop();
        _detachAnim.stop();
        _morphAnim.stop();
        _visAnim.to = targets.v;
        _transAnim.to = targets.t;
        _detachAnim.to = targets.d;
        _morphAnim.to = targets.m;
        _visAnim.start();
        _transAnim.start();
        _detachAnim.start();
        _morphAnim.start();
    }

    // Initialize progress from the initial surfaceState on creation.
    Component.onCompleted: {
        var targets = _targetsForState(surfaceState);
        _visibilityProgress = targets.v;
        _stateTransitionProgress = targets.t;
        _detachProgress = targets.d;
        _morphProgress = targets.m;
        _hoverProgress = _targetHoverProgress();
    }

    // React to external surfaceState changes.
    onSurfaceStateChanged: transitionTo(surfaceState)

    // Let the shared spring behavior absorb hover changes without retrigger loops.
    onHoverIntentChanged: _hoverProgress = _targetHoverProgress()

    NumberAnimation {
        id: _visAnim

        target: root
        property: "_visibilityProgress"
        duration: Services.Motion.number.surfaceDuration
        easing.type: Services.Motion.number.surfaceEasing
    }

    NumberAnimation {
        id: _transAnim

        target: root
        property: "_stateTransitionProgress"
        duration: Services.Motion.number.surfaceDuration
        easing.type: Services.Motion.number.surfaceEasing
    }

    NumberAnimation {
        id: _detachAnim

        target: root
        property: "_detachProgress"
        duration: Services.Motion.number.surfaceDuration
        easing.type: Services.Motion.number.surfaceEasing
    }

    NumberAnimation {
        id: _morphAnim

        target: root
        property: "_morphProgress"
        duration: Services.Motion.number.surfaceDuration
        easing.type: Services.Motion.number.surfaceEasing
    }

    Behavior on _hoverProgress {
        SpringAnimation {
            spring: Services.Motion.hover.spring
            damping: Services.Motion.hover.damping
            mass: Services.Motion.hover.mass
            epsilon: Services.Motion.hover.epsilon
        }
    }

    // Build the contract model from semantic inputs plus owner progress.
    readonly property var model: Model.buildModel({
        section: root.section,
        surfaceState: root.surfaceState,
        surfaceHeight: root.surfaceHeight,
        contentWidth: root.contentWidth,
        contentHeight: root.contentHeight,
        visibilityProgress: root._visibilityProgress,
        stateTransitionProgress: root._stateTransitionProgress,
        detachProgress: root._detachProgress,
        morphProgress: root._morphProgress,
        hoverProgress: root._hoverProgress
    })

    // Derive renderer-facing metrics from the contract model.
    readonly property var metrics: Model.deriveRendererMetrics(root.model)

    // Expose body geometry for child content positioning.
    readonly property real bodyX: metrics.bodyX
    readonly property real bodyY: metrics.bodyY
    readonly property real bodyWidth: metrics.bodyWidth
    readonly property real bodyHeight: metrics.bodyHeight

    implicitWidth: metrics.containerWidth
    implicitHeight: metrics.containerHeight
    width: implicitWidth
    height: implicitHeight

    // Visual constants from model metrics.
    readonly property color fillColor: Services.Color.mSurface
    readonly property color borderColor: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.3)
    readonly property int earRadius: metrics.earRadius
    readonly property int bodyRadius: metrics.bodyRadius
    readonly property bool isLeftSection: root.section === "left"
    readonly property bool isRightSection: root.section === "right"

    // Root-level global motion envelope — body and ears inherit these so
    // the entire surface moves as one continuous object.
    opacity: root.model.globalMotion.opacity
    scale: root.model.globalMotion.scale
    transform: Translate {
        x: root.model.globalMotion.translateX
        y: root.model.globalMotion.translateY
    }

    // Paint the shared left top ear for center and right sections.
    Canvas {
        id: leftEar

        z: 0
        x: 0
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasLeftTopEar
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(w, 0);
            ctx.lineTo(w, h);
            ctx.arc(0, h, curve, 0, -Math.PI / 2, true);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

    // Paint the adaptive body between the edge decorations.
    Canvas {
        id: centerBody

        z: 0
        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: root.bodyHeight
        antialiasing: true
        visible: root.model.state.visibilityProgress > 0
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var radius = Math.min(root.bodyRadius, w / 2, h / 2);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            if (root.isRightSection) {
                // Right: only the bottom-left corner stays rounded.
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h);
                ctx.lineTo(radius, h);
                ctx.quadraticCurveTo(0, h, 0, h - radius);
            } else if (root.isLeftSection) {
                // Left: only the bottom-right corner stays rounded.
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h - radius);
                ctx.quadraticCurveTo(w, h, w - radius, h);
                ctx.lineTo(0, h);
            } else {
                // Center: both bottom corners rounded.
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h - radius);
                ctx.quadraticCurveTo(w, h, w - radius, h);
                ctx.lineTo(radius, h);
                ctx.quadraticCurveTo(0, h, 0, h - radius);
            }
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

    // Paint the left-side bottom ear inside the unified surface tree.
    Canvas {
        id: leftBottomEar

        z: 0
        x: root.metrics.bottomLeftEarX
        y: root.metrics.bottomEarY - 1
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasBottomLeftEar
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.save();
            ctx.translate(w / 2, h / 2);
            ctx.rotate(Math.PI / 2);
            ctx.translate(-w / 2, -h / 2);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(w, h);
            ctx.lineTo(0, h);
            ctx.lineTo(0, 0);
            ctx.arc(w, 0, curve, Math.PI, Math.PI / 2, true);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
            ctx.restore();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

    // Paint the shared right top ear for center and left sections.
    Canvas {
        id: rightEar

        z: 0
        x: root.bodyX + root.bodyWidth - 1
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasTopRightEar
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(0, h);
            ctx.arc(w, h, curve, Math.PI, -Math.PI / 2, false);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

    // Paint the right-side bottom ear inside the unified surface tree.
    Canvas {
        id: rightBottomEar

        z: 0
        x: root.metrics.bottomRightEarX
        y: root.metrics.bottomEarY - 1
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasBottomRightEar
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(w, 0);
            ctx.lineTo(0, 0);
            ctx.arc(0, h, curve, -Math.PI / 2, 0, false);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }
}
