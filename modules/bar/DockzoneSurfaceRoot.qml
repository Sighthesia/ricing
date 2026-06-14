import "."
import "DockzoneSurfaceModel.js" as Model
import QtQuick
import QtQuick.Shapes
import "../../services" as Services

// Surface-local owner for a dockzone path — first validated on center.
// Owns semantic state input and animated canonical progress drivers.
Item {
    id: root

    // High-level semantic inputs from the section owner.
    required property string section
    required property string screenName
    required property real screenX
    required property real screenY
    required property real screenWidth
    required property real screenHeight
    property real windowX: 0
    property string surfaceState: "attached"
    property bool hoverIntent: false
    required property real surfaceHeight
    required property real contentWidth
    required property real contentHeight
    property real blurSourceOffsetX: 0
    property real sectionPushOffsetX: 0

    // Optional vertical expansion (island-style): the body grows downward by
    // expandHeight and widens to expandWidth to host an attached popup (the tray
    // menu) inside this same surface. Zero is a no-op for normal dockzones.
    property real expandHeight: 0
    property real expandWidth: 0

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

    // Expose body geometry for child content positioning. The animated popup
    // expansion is applied here as a lightweight additive override on top of the
    // resting model geometry, so the per-frame spring never re-runs the JS
    // model (which would thrash the GC and stutter the animation).
    readonly property real bodyX: metrics.bodyX
    readonly property real bodyY: metrics.bodyY
    readonly property real bodyWidth: Math.max(metrics.bodyWidth, root.expandWidth)
    readonly property real bodyHeight: metrics.bodyHeight + root.expandHeight
    // Natural (un-extended) body width and the resting top-band height, so
    // callers can lay popup content beneath the widget row.
    readonly property real naturalBodyWidth: metrics.naturalBodyWidth
    readonly property real topBandHeight: metrics.topBandHeight
    readonly property real contentShiftX: metrics.contentShiftX

    implicitWidth: metrics.containerWidth + Math.max(0, root.expandWidth - metrics.bodyWidth)
    implicitHeight: metrics.containerHeight + root.expandHeight
    width: implicitWidth
    height: implicitHeight

    // Visual constants from model metrics.
    readonly property color fillColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    readonly property color borderColor: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.3)
    readonly property int earRadius: metrics.earRadius
    readonly property int bodyRadius: metrics.bodyRadius
    readonly property bool isLeftSection: root.section === "left"
    readonly property bool isRightSection: root.section === "right"
    readonly property int earBlurStripCount: Math.max(0, root.earRadius - Services.SettingsService.blurRegionInset * 2)
    readonly property real pushShrinkLimit: Math.max(0, root.bodyWidth - root.earRadius)
    readonly property real bodyShrinkX: (root.isLeftSection || root.isRightSection) ? Math.min(root.sectionPushOffsetX, root.pushShrinkLimit) : 0
    readonly property real residualPushOffsetX: (root.isLeftSection || root.isRightSection) ? Math.max(0, root.sectionPushOffsetX - root.pushShrinkLimit) : 0
    readonly property real pushedBodyX: root.bodyX
    readonly property real pushedBodyWidth: Math.max(root.earRadius, root.bodyWidth - root.bodyShrinkX)
    readonly property real visualOffsetX: root.isRightSection ? root.bodyShrinkX : 0
    readonly property real visualBodyX: root.pushedBodyX + root.visualOffsetX
    readonly property real pushedBodyRadius: Math.min(root.bodyRadius, root.pushedBodyWidth / 2, root.bodyHeight / 2)
    readonly property bool earBlurEnabled: root.bodyShrinkX < 0.5
    readonly property bool blurVisible: root.model.state.visibilityProgress > 0
        && (!root.isLeftSection || root.residualPushOffsetX < root.pushedBodyWidth)
        && (!root.isRightSection || root.residualPushOffsetX < root.pushedBodyWidth)

    function _earCutX(localY) {
        var radius = Math.max(1, root.earRadius)
        var clampedY = Math.max(0, Math.min(radius, localY))
        var dy = radius - clampedY

        return Math.sqrt(Math.max(0, radius * radius - dy * dy))
    }

    function _stripParts(repeater, active) {
        var parts = []

        if (!active)
            return parts

        for (var i = 0; i < repeater.count; ++i) {
            var item = repeater.itemAt(i)

            if (item && item.width > 0 && item.height > 0) {
                parts.push({
                    item: item,
                    radius: 0,
                    topLeftRadius: 0,
                    topRightRadius: 0,
                    bottomLeftRadius: 0,
                    bottomRightRadius: 0
                })
            }
        }

        return parts
    }

    function playRipplePulse() {
        if (Services.SettingsService.appearance.ripplePulseFullscreen)
            return

        rippleRing.width = 16
        rippleRing.opacity = 0
        rippleGlow.opacity = 0
        rippleAfterglowNear.opacity = 0
        rippleAfterglowFar.opacity = 0
        ripplePulse.restart()
    }

    onVisibleChanged: {
        if (!visible)
            ripplePulse.stop()
    }

    // Blur source parts for body and ears.
    // Ear parts are one-pixel strips so wl_region can approximate the concave arcs
    // without unsupported subtract/ellipse composition.
    readonly property var blurParts: root.blurVisible ? [
        {
            item: centerBodyBlurSource,
            radius: root.pushedBodyRadius,
            topLeftRadius: 0,
            topRightRadius: 0,
            bottomLeftRadius: root.isRightSection || (!root.isLeftSection && !root.isRightSection) ? root.pushedBodyRadius : 0,
            bottomRightRadius: root.isLeftSection || (!root.isLeftSection && !root.isRightSection) ? root.pushedBodyRadius : 0
        }
    ].concat(
        root._stripParts(leftEarBlurStrips, root.earBlurEnabled && leftEar.visible),
        root._stripParts(rightEarBlurStrips, root.earBlurEnabled && rightEar.visible),
        root._stripParts(leftBottomEarBlurStrips, root.earBlurEnabled && leftBottomEar.visible),
        root._stripParts(rightBottomEarBlurStrips, root.earBlurEnabled && rightBottomEar.visible)
    ) : []

    // Root-level global motion envelope — body and ears inherit these so
    // the entire surface moves as one continuous object.
    opacity: root.model.globalMotion.opacity
    scale: root.model.globalMotion.scale
    transform: Translate {
        x: root.model.globalMotion.translateX
        y: root.model.globalMotion.translateY
    }

    // --- Unified silhouette fill + border ---
    // Trace the whole section (body + its two ears) as ONE continuous outer
    // contour, then fill once and stroke once. A single fill applies the
    // semi-transparent surface alpha exactly once per pixel, so the ear/body
    // joins have no double-blended seam. A single stroke follows only the true
    // outer edge, so the border never paints a highlight line along the joins.
    // --- Unified silhouette fill + border ---
    // Trace the whole section (body + its two ears) as ONE continuous outer
    // contour, then fill once and stroke once. Rendered via QtQuick.Shapes so
    // geometry changes during the expand spring are GPU-tessellated each frame
    // instead of CPU-repainted like the previous Canvas (which re-rasterized the
    // whole outline every frame and made the expand animation stutter).
    Shape {
        id: silhouetteFill

        z: 0
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        visible: root.model.state.visibilityProgress > 0

        // SVG outline mirroring the previous Canvas paths. Concave ear fillets
        // are quarter-circle arcs (sweep flag 0, matching AttachedIslandSurface).
        readonly property string outline: {
            var er = root.earRadius
            var ox = root.visualOffsetX
            var bx = root.visualBodyX
            var bw = root.pushedBodyWidth
            var bh = root.bodyHeight

            if (bw <= 0 || bh <= 0)
                return ""

            var bodyRightX = bx + bw
            var radius = Math.min(root.bodyRadius, bw / 2, bh / 2)

            if (root.isLeftSection) {
                // Body (bodyX=0) + top-right ear + bottom-left ear.
                return "M " + ox + " 0"
                    + " L " + (bodyRightX + er) + " 0"
                    + " A " + er + " " + er + " 0 0 0 " + bodyRightX + " " + er
                    + " L " + bodyRightX + " " + (bh - radius)
                    + " Q " + bodyRightX + " " + bh + " " + (bodyRightX - radius) + " " + bh
                    + " L " + (ox + er) + " " + bh
                    + " A " + er + " " + er + " 0 0 0 " + ox + " " + (bh + er)
                    + " L " + ox + " 0 Z"
            } else if (root.isRightSection) {
                // Body (bodyX=er) + top-left ear + bottom-right ear.
                return "M " + ox + " 0"
                    + " L " + bodyRightX + " 0"
                    + " L " + bodyRightX + " " + (bh + er)
                    + " A " + er + " " + er + " 0 0 0 " + (bodyRightX - er) + " " + bh
                    + " L " + (bx + radius) + " " + bh
                    + " Q " + bx + " " + bh + " " + bx + " " + (bh - radius)
                    + " L " + bx + " " + er
                    + " A " + er + " " + er + " 0 0 0 " + ox + " 0 Z"
            }

            // Center: both top ears + both rounded bottom corners.
            return "M 0 0"
                + " L " + (bodyRightX + er) + " 0"
                + " A " + er + " " + er + " 0 0 0 " + bodyRightX + " " + er
                + " L " + bodyRightX + " " + (bh - radius)
                + " Q " + bodyRightX + " " + bh + " " + (bodyRightX - radius) + " " + bh
                + " L " + (bx + radius) + " " + bh
                + " Q " + bx + " " + bh + " " + bx + " " + (bh - radius)
                + " L " + bx + " " + er
                + " A " + er + " " + er + " 0 0 0 " + (bx - er) + " 0 Z"
        }

        ShapePath {
            fillColor: root.fillColor
            strokeColor: root.borderColor
            strokeWidth: 1

            PathSvg {
                path: silhouetteFill.outline
            }
        }
    }

    Connections {
        target: Services.IslandService

        function onRipplePulseTokenChanged() {
            if (Services.IslandService.ripplePulseToken > 0)
                root.playRipplePulse()
        }
    }

    // Mask the shared screen-origin ripple to this dockzone surface only.
    Item {
        id: rippleLayer

        x: centerBody.x
        y: centerBody.y
        width: centerBody.width
        height: centerBody.height
        clip: true
        visible: rippleRing.opacity > 0.01
        z: 999

        readonly property real originX: root.screenWidth / 2 - root.windowX - centerBody.x
        readonly property real originY: -centerBody.y
        readonly property real maxDiameter: Math.ceil(Math.sqrt(root.screenWidth * root.screenWidth + root.screenHeight * root.screenHeight) * 2)

        Rectangle {
            id: rippleGlow

            width: rippleRing.width
            height: width
            x: rippleLayer.originX - width / 2
            y: rippleLayer.originY - height / 2
            radius: width / 2
            color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
            opacity: 0
        }

        Rectangle {
            id: rippleRing

            width: 16
            height: width
            x: rippleLayer.originX - width / 2
            y: rippleLayer.originY - height / 2
            radius: width / 2
            color: "transparent"
            border.width: Math.max(8, Math.min(18, width * 0.018))
            border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.9)
            opacity: 0
        }

        Rectangle {
            id: rippleAfterglowNear

            width: 16
            height: width
            x: rippleLayer.originX - width / 2
            y: rippleLayer.originY - height / 2
            radius: width / 2
            color: "transparent"
            border.width: Math.max(18, Math.min(42, width * 0.034))
            border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.38)
            opacity: 0
        }

        Rectangle {
            id: rippleAfterglowFar

            width: 16
            height: width
            x: rippleLayer.originX - width / 2
            y: rippleLayer.originY - height / 2
            radius: width / 2
            color: "transparent"
            border.width: Math.max(28, Math.min(64, width * 0.052))
            border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.22)
            opacity: 0
        }

        ParallelAnimation {
            id: ripplePulse

            NumberAnimation { target: rippleRing; property: "width"; from: 16; to: rippleLayer.maxDiameter; duration: 1800; easing.type: Easing.OutCubic }
            NumberAnimation { target: rippleRing; property: "opacity"; from: 0.95; to: 0; duration: 1800; easing.type: Easing.OutCubic }
            NumberAnimation { target: rippleGlow; property: "opacity"; from: 0.34; to: 0; duration: 1450; easing.type: Easing.OutCubic }
            NumberAnimation { target: rippleAfterglowNear; property: "width"; from: 16; to: rippleLayer.maxDiameter * 0.98; duration: 2050; easing.type: Easing.OutCubic }
            NumberAnimation { target: rippleAfterglowNear; property: "opacity"; from: 0.28; to: 0; duration: 2050; easing.type: Easing.OutCubic }
            NumberAnimation { target: rippleAfterglowFar; property: "width"; from: 16; to: rippleLayer.maxDiameter * 0.94; duration: 2300; easing.type: Easing.OutCubic }
            NumberAnimation { target: rippleAfterglowFar; property: "opacity"; from: 0.16; to: 0; duration: 2300; easing.type: Easing.OutCubic }
        }
    }

    // --- Left top ear geometry (center and right sections) ---
    // Geometry-only marker: positions the blur strips and the silhouette path.
    Item {
        id: leftEar

        z: 0
        x: root.metrics.hasLeftTopEar ? root.visualBodyX - root.earRadius : root.visualOffsetX
        y: 0
        width: root.earRadius
        height: root.earRadius
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasLeftTopEar
    }

    // Body geometry marker — drives the blur source and content positioning.
    Item {
        id: centerBody

        z: 0
        x: root.visualBodyX
        y: root.bodyY
        width: root.pushedBodyWidth
        height: root.bodyHeight
        visible: root.model.state.visibilityProgress > 0
    }

    // Keep the bar blur source in normal item geometry, not inside Canvas paint nodes.
    // Full-size: the blur region matches the painted body edge so the acrylic
    // covers the fill completely with no un-blurred semi-transparent rim.
        Item {
            id: centerBodyBlurSource

        x: centerBody.x + root.blurSourceOffsetX
        y: centerBody.y
        width: centerBody.width
        height: centerBody.height
    }

    // Blur strips for the left top ear; each strip follows the Canvas arc math.
    Repeater {
        id: leftEarBlurStrips

        model: root.earBlurEnabled ? root.earBlurStripCount : 0

        Item {
            required property int index
            readonly property real localY: Services.SettingsService.blurRegionInset + index
            readonly property real cutX: root._earCutX(localY)

            x: leftEar.x + cutX + root.blurSourceOffsetX
            y: leftEar.y + localY
            width: Math.max(0, root.earRadius - Services.SettingsService.blurRegionInset - cutX)
            height: 1
        }
    }

    // Blur strips for the right top ear; mirrored from the left top ear.
    Repeater {
        id: rightEarBlurStrips

        model: root.earBlurEnabled ? root.earBlurStripCount : 0

        Item {
            required property int index
            readonly property real localY: Services.SettingsService.blurRegionInset + index
            readonly property real cutX: root._earCutX(localY)
            readonly property real fillRight: root.earRadius - cutX

            x: rightEar.x + Services.SettingsService.blurRegionInset + root.blurSourceOffsetX
            y: rightEar.y + localY
            width: Math.max(0, fillRight - Services.SettingsService.blurRegionInset)
            height: 1
        }
    }

    // Blur strips for the left bottom ear; this matches its rotated Canvas path.
    Repeater {
        id: leftBottomEarBlurStrips

        model: root.earBlurEnabled ? root.earBlurStripCount : 0

        Item {
            required property int index
            readonly property real localY: Services.SettingsService.blurRegionInset + index
            readonly property real cutX: root._earCutX(localY)
            readonly property real fillRight: root.earRadius - cutX

            x: leftBottomEar.x + Services.SettingsService.blurRegionInset + root.blurSourceOffsetX
            y: leftBottomEar.y + localY
            width: Math.max(0, fillRight - Services.SettingsService.blurRegionInset)
            height: 1
        }
    }

    // Blur strips for the right bottom ear; same orientation as the left top ear.
    Repeater {
        id: rightBottomEarBlurStrips

        model: root.earBlurEnabled ? root.earBlurStripCount : 0

        Item {
            required property int index
            readonly property real localY: Services.SettingsService.blurRegionInset + index
            readonly property real cutX: root._earCutX(localY)

            x: rightBottomEar.x + cutX + root.blurSourceOffsetX
            y: rightBottomEar.y + localY
            width: Math.max(0, root.earRadius - Services.SettingsService.blurRegionInset - cutX)
            height: 1
        }
    }

    // Left bottom ear stays in the continuous section shape.
    Item {
        id: leftBottomEar

        z: 0
        x: root.visualOffsetX + root.metrics.bottomLeftEarX
        y: root.bodyHeight - 1
        width: root.earRadius
        height: root.earRadius
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasBottomLeftEar
    }

    // --- Right top ear geometry (center and left sections) ---
    // Geometry-only marker for the blur strips and silhouette path.
    Item {
        id: rightEar

        z: 0
        x: root.visualBodyX + root.pushedBodyWidth
        y: 0
        width: root.earRadius
        height: root.earRadius
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasTopRightEar
    }

    // Right bottom ear stays in the continuous section shape.
    Item {
        id: rightBottomEar

        z: 0
        x: root.visualBodyX + root.pushedBodyWidth - root.earRadius
        y: root.bodyHeight - 1
        width: root.earRadius
        height: root.earRadius
        visible: root.model.state.visibilityProgress > 0 && root.metrics.hasBottomRightEar
    }

}
