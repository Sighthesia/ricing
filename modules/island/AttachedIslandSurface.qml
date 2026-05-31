import QtQuick
import QtQuick.Shapes
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

    // Animated size: body width grows by the two ear radii, matching the
    // legacy IslandBody size semantics (targetW + earRadius*2 / targetH).
    width: targetBodyWidth + earRadius * 2
    height: targetBodyHeight
    implicitWidth: width
    implicitHeight: height

    // Animated corner radius, exposed so callers can read the live value.
    property real bodyRadius: targetRadius

    readonly property int earBlurStripCount: Math.max(0, root.earRadius - Services.SettingsService.blurRegionInset * 2)

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
            var er = root.earRadius
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

        ShapePath {
            fillColor: root.surfaceColor
            strokeWidth: 0

            PathSvg {
                path: silhouetteFill.outline
            }
        }
    }

    // --- Left ear geometry (connects body to screen top-left) ---
    // Geometry-only marker: positions the blur strips and the silhouette path.
    Item {
        id: leftEar
        x: bodyRect.x - root.earRadius
        y: 0
        width: root.earRadius
        height: root.earRadius
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
            width: Math.max(0, root.earRadius - Services.SettingsService.blurRegionInset - cutX)
            height: 1
        }
    }

    // --- Body shell ---
    // Transparent clip container; the actual fill is painted by silhouetteFill.
    // Caller content lands here via the default bodyContent slot.
    Item {
        id: bodyRect
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
        onWidthChanged: {
            blurLeadW = Math.max(0, _lastW - width) * blurLeadFactor
            _lastW = width
        }
        onHeightChanged: {
            blurLeadH = Math.max(0, _lastH - height) * blurLeadFactor
            _lastH = height
        }

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
    }

    // Blur strips for the right top ear; mirrored from the left top ear.
    Repeater {
        id: rightEarBlurStrips

        model: root.earBlurStripCount

        Item {
            required property int index
            readonly property real localY: Services.SettingsService.blurRegionInset + index
            readonly property real cutX: root._earCutX(localY)
            readonly property real fillRight: root.earRadius - cutX

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
        width: root.earRadius
        height: root.earRadius
        visible: root.height > 0
    }
}
