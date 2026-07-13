import QtQuick
import QtQuick.Shapes
import "../shaders"
import "../../services" as Services

// Reusable attached-island shell: a center body plus edge-attached ears that
// spring-morph as one continuous silhouette. Callers feed target geometry
// (targetBodyWidth/Height/Radius) and place content in the body clip slot via
// the default content property; the shell owns the spring deformation, the
// unified outline fill, the ear blur strips, the velocity-led blur source, and
// exposes blurParts for the host window's blur region to track.
Item {
    id: root

    // Host content into the body clip container by default.
    default property alias bodyContent: bodyRect.data

    // Target geometry fed by the caller (driven by their own state/hover).
    property int targetBodyWidth: 220
    property int targetBodyHeight: 44
    property int targetRadius: 14
    property int earRadius: 24
    property color surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    property bool highlightIntent: false
    readonly property color glassThemeColor: Services.SettingsService.appearance.glassThemeAdaptive
        ? Services.Color.mPrimary
        : Services.Color.mOutline
    readonly property color glassHighlightBaseColor: Services.SettingsService.appearance.glassThemeAdaptive
        ? Services.Color.mPrimary
        : Services.Color.mOnSurface
    property real glassGlowWidth: Services.SettingsService.appearance.glassGlowWidth
    property real glassHighlightWidth: Services.SettingsService.appearance.glassHighlightWidth

    // Wallpaper-driven glass edge color sampler.
    GlassEdgeEffect {
        id: edgeSampler
        surfaceScreenX: root.rippleScreenX + (root.rippleScreenWidth - root.width) / 2
        surfaceScreenY: root.rippleScreenY
        surfaceWidth: root.width
        surfaceHeight: root.height
        screenWidth: root.rippleScreenWidth
        screenHeight: root.rippleScreenHeight
        fallbackColor: root.glassThemeColor
        fallbackHighlightColor: root.glassHighlightBaseColor
    }

    property color glassGlowColor: Qt.rgba(
        edgeSampler.baseColor.r,
        edgeSampler.baseColor.g,
        edgeSampler.baseColor.b,
        Services.SettingsService.appearance.glassGlowIntensity * (highlightIntent ? 1.35 : 1)
    )
    property color glassHighlightColor: Qt.rgba(
        edgeSampler.baseHighlightColor.r,
        edgeSampler.baseHighlightColor.g,
        edgeSampler.baseHighlightColor.b,
        Services.SettingsService.appearance.glassHighlightIntensity * (highlightIntent ? 1.25 : 1)
    )
    property real rippleScreenX: 0
    property real rippleScreenY: 0
    property real rippleScreenWidth: Screen.width
    property real rippleScreenHeight: Screen.height

    // Animated size: body width grows by the two ear radii, matching the
    // legacy IslandBody size semantics (targetW + earRadius*2 / targetH).
    width: targetBodyWidth + earRadius * 2
    height: targetBodyHeight
    implicitWidth: width
    implicitHeight: height

    // Animated corner radius, exposed so callers can read the live value.
    property real bodyRadius: targetRadius

    // Live ear radius used for the DRAWN ear geometry. The outer footprint
    // (width == targetBodyWidth + earRadius*2) keeps using the static earRadius
    // so caller centering math is unchanged, but the visible ears scale down as
    // the body collapses toward zero so they shrink in sync instead of staying
    // full-size until the body vanishes. Ramps to full radius well before any
    // normal resting size (e.g. the island never collapses this small), so it
    // is a no-op for existing callers and only affects collapse-to-zero popups.
    readonly property real liveEarRadius: {
        var bodySpan = Math.min(root.width - root.earRadius * 2, root.height)
        var ramp = Math.max(0, Math.min(1, bodySpan / (root.earRadius * 2)))
        return root.earRadius * ramp
    }

    readonly property int earBlurStripCount: Math.max(0, root.liveEarRadius - Services.SettingsService.blurRegionInset * 2)

    Behavior on glassGlowColor {
        ColorAnimation {
            duration: root.highlightIntent ? 180 : 260
            easing.type: Easing.OutCubic
        }
    }

    Behavior on glassHighlightColor {
        ColorAnimation {
            duration: root.highlightIntent ? 180 : 260
            easing.type: Easing.OutCubic
        }
    }

    Behavior on glassGlowWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Behavior on glassHighlightWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    function _earCutX(localY) {
        var radius = Math.max(1, root.liveEarRadius)
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

    // Blur source parts for the center island body and top ears. The body
    // source leads inward during collapse (see bodyBlurSource) so the async,
    // polish-coalesced compositor blur region never spills past the silhouette
    // while it lags the per-frame size.
    readonly property var blurParts: [
        {
            item: bodyBlurSource,
            radius: root.bodyRadius,
            topLeftRadius: 0,
            topRightRadius: 0,
            bottomLeftRadius: root.bodyRadius,
            bottomRightRadius: root.bodyRadius
        }
    ].concat(
        root._stripParts(leftEarBlurStrips, leftEar.visible),
        root._stripParts(rightEarBlurStrips, rightEar.visible)
    )

    // SpringAnimation for organic feel. Direction-aware damping makes the
    // expand lively (lower damping) and the collapse settle cleanly (higher
    // damping), driven off the dedicated island-expand spring profile.
    property real wDamping: Services.Motion.islandExpand.dampingCollapse
    property real hDamping: Services.Motion.islandExpand.dampingCollapse
    property real rDamping: Services.Motion.islandExpand.dampingCollapse

    onTargetBodyWidthChanged: wDamping = (targetBodyWidth + earRadius * 2 > width)
        ? Services.Motion.islandExpand.dampingExpand
        : Services.Motion.islandExpand.dampingCollapse
    onTargetBodyHeightChanged: hDamping = (targetBodyHeight > height)
        ? Services.Motion.islandExpand.dampingExpand
        : Services.Motion.islandExpand.dampingCollapse
    onTargetRadiusChanged: rDamping = (targetRadius > bodyRadius)
        ? Services.Motion.islandExpand.dampingExpand
        : Services.Motion.islandExpand.dampingCollapse

    Behavior on width {
        SpringAnimation {
            spring: Services.Motion.islandExpand.spring
            mass: Services.Motion.islandExpand.mass
            damping: root.wDamping
            epsilon: Services.Motion.islandExpand.epsilon
        }
    }
    Behavior on height {
        SpringAnimation {
            spring: Services.Motion.islandExpand.spring
            mass: Services.Motion.islandExpand.mass
            damping: root.hDamping
            epsilon: Services.Motion.islandExpand.epsilon
        }
    }
    Behavior on bodyRadius {
        SpringAnimation {
            spring: Services.Motion.islandExpand.spring
            mass: Services.Motion.islandExpand.mass
            damping: root.rDamping
            epsilon: Services.Motion.islandExpand.epsilon
        }
    }

    // --- Unified silhouette fill ---
    // Paint the body and both top ears as one continuous closed path. A single
    // fill applies the semi-transparent surface alpha exactly once per pixel
    // even where subpaths meet, so the ear/body joins have no double-blended
    // seam or sub-pixel gap. Rendered via QtQuick.Shapes so geometry changes
    // during the expand spring are GPU-tessellated each frame instead of
    // CPU-repainted like the previous Canvas.
    Shape {
        id: silhouetteFill
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        // Build the same outline the Canvas drew, as an SVG path string. Ears
        // present: left ear -> top -> right ear concave fillet -> body right
        // -> rounded bottom -> body left -> left ear concave fillet -> close.
        readonly property string outline: {
            var er = root.liveEarRadius
            var bodyX = bodyRect.x
            var bodyW = bodyRect.width
            var bodyH = bodyRect.height

            if (bodyW <= 0 || bodyH <= 0)
                return ""

            var bodyRightX = bodyX + bodyW
            var radius = Math.min(root.bodyRadius, bodyW / 2, bodyH / 2)
            var hasEars = leftEar.visible && rightEar.visible

            if (hasEars) {
                return "M " + leftEar.x + " 0"
                    + " L " + (bodyRightX + er) + " 0"
                    + " A " + er + " " + er + " 0 0 0 " + bodyRightX + " " + er
                    + " L " + bodyRightX + " " + (bodyH - radius)
                    + " Q " + bodyRightX + " " + bodyH + " " + (bodyRightX - radius) + " " + bodyH
                    + " L " + (bodyX + radius) + " " + bodyH
                    + " Q " + bodyX + " " + bodyH + " " + bodyX + " " + (bodyH - radius)
                    + " L " + bodyX + " " + er
                    + " A " + er + " " + er + " 0 0 0 " + leftEar.x + " 0"
                    + " Z"
            }

            // Body only: square top, rounded bottom corners.
            return "M " + bodyX + " 0"
                + " L " + bodyRightX + " 0"
                + " L " + bodyRightX + " " + (bodyH - radius)
                + " Q " + bodyRightX + " " + bodyH + " " + (bodyRightX - radius) + " " + bodyH
                + " L " + (bodyX + radius) + " " + bodyH
                + " Q " + bodyX + " " + bodyH + " " + bodyX + " " + (bodyH - radius)
                + " Z"
        }

        // Glass strokes omit the screen-attached top edge while the fill stays closed.
        readonly property string strokeOutline: {
            var er = root.liveEarRadius
            var bodyX = bodyRect.x
            var bodyW = bodyRect.width
            var bodyH = bodyRect.height

            if (bodyW <= 0 || bodyH <= 0)
                return ""

            var bodyRightX = bodyX + bodyW
            var radius = Math.min(root.bodyRadius, bodyW / 2, bodyH / 2)
            var hasEars = leftEar.visible && rightEar.visible
            var topInset = hasEars ? Math.min(er, Math.max(root.glassGlowWidth, root.glassHighlightWidth) + 2) : 2

            if (hasEars) {
                // Enter from above the visible surface so both full ear arcs remain stroked
                // without a connecting top edge.
                return "M " + leftEar.x + " " + (-topInset)
                    + " L " + leftEar.x + " 0"
                    + " A " + er + " " + er + " 0 0 1 " + bodyX + " " + er
                    + " L " + bodyX + " " + (bodyH - radius)
                    + " Q " + bodyX + " " + bodyH + " " + (bodyX + radius) + " " + bodyH
                    + " L " + (bodyRightX - radius) + " " + bodyH
                    + " Q " + bodyRightX + " " + bodyH + " " + bodyRightX + " " + (bodyH - radius)
                    + " L " + bodyRightX + " " + er
                    + " A " + er + " " + er + " 0 0 1 " + (bodyRightX + er) + " 0"
                    + " L " + (bodyRightX + er) + " " + (-topInset)
            }

            return "M " + (bodyX + radius) + " " + bodyH
                + " Q " + bodyX + " " + bodyH + " " + bodyX + " " + (bodyH - radius)
                + " L " + bodyX + " " + topInset
                + " M " + bodyRightX + " " + topInset
                + " L " + bodyRightX + " " + (bodyH - radius)
                + " Q " + bodyRightX + " " + bodyH + " " + (bodyRightX - radius) + " " + bodyH
        }

        // Low-energy theme glow keeps the silhouette legible on busy backdrops.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.glassGlowColor
            strokeWidth: root.glassGlowWidth
            capStyle: ShapePath.FlatCap

            PathSvg {
                path: silhouetteFill.strokeOutline
            }
        }

        // Surface fill remains geometrically identical to the existing shell.
        ShapePath {
            fillColor: root.surfaceColor
            strokeWidth: 0

            PathSvg {
                path: silhouetteFill.outline
            }
        }

        // Fine refractive highlight provides the primary liquid-glass edge.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.glassHighlightColor
            strokeWidth: root.glassHighlightWidth
            capStyle: ShapePath.FlatCap

            PathSvg {
                path: silhouetteFill.strokeOutline
            }
        }
    }

    // --- Left ear geometry (connects body to screen top-left) ---
    // Geometry-only marker: positions the blur strips and the silhouette path.
    Item {
        id: leftEar
        x: bodyRect.x - root.liveEarRadius
        y: 0
        width: root.liveEarRadius
        height: root.liveEarRadius
        visible: root.height > 0
    }

    // Blur strips for the left top ear; each strip follows the Canvas arc math.
    Repeater {
        id: leftEarBlurStrips

        model: root.earBlurStripCount

        Item {
            required property int index
            readonly property real localY: Services.SettingsService.blurRegionInset + index
            readonly property real cutX: root._earCutX(localY)

            x: leftEar.x + cutX
            y: leftEar.y + localY
            width: Math.max(0, root.liveEarRadius - Services.SettingsService.blurRegionInset - cutX)
            height: 1
        }
    }

    // --- Body shell ---
    // Transparent clip container; the actual fill is painted by silhouetteFill.
    // Caller content lands here via the default bodyContent slot.
    Item {
        id: bodyRect
        z: 1
        x: root.earRadius
        y: 0
        width: root.width - root.earRadius * 2
        height: root.height
        clip: true

        // Velocity-based shrink lead for the blur source. The async,
        // polish-coalesced compositor blur region trails the per-frame body
        // size, so during a fast collapse the lagged region would spill past
        // the shrinking silhouette. We lead the blur inward by an amount
        // proportional to the current per-frame shrink speed: zero at rest and
        // at motion onset (no sudden jump), largest mid-collapse (absorbs the
        // lag), zero again once settled (blur sits flush). Expansion never
        // overflows, so growth produces no lead.
        readonly property real blurLeadFactor: 3
        property real blurLeadW: 0
        property real blurLeadH: 0
        property real _lastW: width
        property real _lastH: height

        Timer {
            id: blurLeadResetTimer

            interval: 40
            repeat: false
            onTriggered: {
                bodyRect.blurLeadW = 0
                bodyRect.blurLeadH = 0
            }
        }

        function _updateBlurLead() {
            blurLeadW = Math.max(0, _lastW - width) * blurLeadFactor
            blurLeadH = Math.max(0, _lastH - height) * blurLeadFactor
            _lastW = width
            _lastH = height

            if (blurLeadW > 0 || blurLeadH > 0)
                blurLeadResetTimer.restart()
            else
                blurLeadResetTimer.stop()
        }

        onWidthChanged: _updateBlurLead()
        onHeightChanged: _updateBlurLead()

        // Blur source for the body. Follows the live body size continuously so
        // the blur shrinks smoothly with the silhouette, inset by the velocity
        // lead on the three edges that move during collapse (bottom, left,
        // right); the top edge is pinned to the screen and never overflows.
        Item {
            id: bodyBlurSource
            x: Math.min(bodyRect.blurLeadW / 2, bodyRect.width / 2)
            y: 0
            width: Math.max(0, bodyRect.width - bodyRect.blurLeadW)
            height: Math.max(0, bodyRect.height - bodyRect.blurLeadH)
        }

        // Mask the screen-origin ripple to the shell surface only.
        Item {
            id: rippleLayer

            anchors.fill: parent
            visible: Services.RipplePulseService.active
            z: 999

            readonly property real originX: root.rippleScreenWidth / 2 - islandBody.x - bodyRect.x
            readonly property real originY: -bodyRect.y
            readonly property real maxDiameter: Math.ceil(Math.sqrt(root.rippleScreenWidth * root.rippleScreenWidth + root.rippleScreenHeight * root.rippleScreenHeight) * 2)

            Rectangle {
                id: rippleTrailBand

                width: Services.RipplePulseService.trailDiameter(rippleLayer.maxDiameter)
                height: width
                x: rippleLayer.originX - width / 2
                y: rippleLayer.originY - height / 2
                radius: width / 2
                color: "transparent"
                border.width: Math.max(96, Math.min(360, rippleRing.border.width * 16))
                border.color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.78)
                opacity: Services.RipplePulseService.trailOpacity()
            }

            Rectangle {
                id: rippleGlow

                width: Services.RipplePulseService.diameter(rippleLayer.maxDiameter)
                height: width
                x: rippleLayer.originX - width / 2
                y: rippleLayer.originY - height / 2
                radius: width / 2
                color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
                opacity: Services.SettingsService.appearance.ripplePulseFullscreen ? 0 : Services.RipplePulseService.glowOpacity()
                scale: 1
            }

            Rectangle {
                id: rippleRing

                width: Services.RipplePulseService.diameter(rippleLayer.maxDiameter)
                height: width
                x: rippleLayer.originX - width / 2
                y: rippleLayer.originY - height / 2
                radius: width / 2
                color: "transparent"
                border.width: Math.max(8, Math.min(18, width * 0.018))
                border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.9)
                opacity: Services.SettingsService.appearance.ripplePulseFullscreen ? 0 : Services.RipplePulseService.ringOpacity()
                scale: 1
            }
        }
    }

    // Blur strips for the right top ear; mirrored from the left top ear.
    Repeater {
        id: rightEarBlurStrips

        model: root.earBlurStripCount

        Item {
            required property int index
            readonly property real localY: Services.SettingsService.blurRegionInset + index
            readonly property real cutX: root._earCutX(localY)
            readonly property real fillRight: root.liveEarRadius - cutX

            x: rightEar.x + Services.SettingsService.blurRegionInset
            y: rightEar.y + localY
            width: Math.max(0, fillRight - Services.SettingsService.blurRegionInset)
            height: 1
        }
    }

    // --- Right ear geometry (connects body to screen top-right) ---
    // Geometry-only marker: positions the blur strips and the silhouette path.
    Item {
        id: rightEar
        x: bodyRect.x + bodyRect.width
        y: 0
        width: root.liveEarRadius
        height: root.liveEarRadius
        visible: root.height > 0
    }
}
