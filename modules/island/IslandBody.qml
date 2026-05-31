import QtQuick
import QtQuick.Shapes
import "../bar" as Bar
import "../../services" as Services

// Animated island body: expands from collapsed clock to full launcher panel.
Item {
    id: root

    required property string screenName

    // Geometry constants.
    readonly property int collapsedW: 220
    readonly property int collapsedH: Services.BarLayoutService.barHeight
    readonly property int expandedW: 480
    readonly property int expandedH: 420
    readonly property int earRadius: 24
    readonly property int collapsedHorizontalPadding: 16
    readonly property int hoverWLift: 12
    readonly property int hoverHLift: 4
    readonly property int hoverRadiusLift: 2
    readonly property color surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    readonly property var centerWidgets: Services.BarLayoutService.sectionWidgets("center")
    readonly property bool showManagedCenterWidgets: !Services.IslandService.expanded
        && root.centerWidgets.length > 0
    readonly property real collapsedContentWidth: collapsedContentLoader.item
        ? collapsedContentLoader.item.implicitWidth + collapsedHorizontalPadding
        : collapsedW

    // Animated dimensions driven by island state and passive hover intent.
    property int targetW: Services.IslandService.expanded
        ? expandedW
        : collapsedContentWidth + (hoverHandler.hovered ? hoverWLift : 0)
    property int targetH: Services.IslandService.expanded
        ? expandedH
        : collapsedH + (hoverHandler.hovered ? hoverHLift : 0)
    property int targetR: Services.IslandService.expanded
        ? 24
        : 14 + (hoverHandler.hovered ? hoverRadiusLift : 0)

    width: targetW + earRadius * 2
    height: targetH
    implicitWidth: width
    implicitHeight: height

    property real bodyRadius: targetR
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

    // Forward widget-aware context menu requests from center widget wrappers.
    function openWidgetContextMenu(instanceKey, widgetId, clickX) {
        Services.BarLayoutService.openContextMenu(clickX, instanceKey, widgetId)
    }

    // SpringAnimation for organic feel. Direction-aware damping makes the
    // expand lively (lower damping) and the collapse settle cleanly (higher
    // damping), driven off the dedicated island-expand spring profile.
    property real wDamping: Services.Motion.islandExpand.dampingCollapse
    property real hDamping: Services.Motion.islandExpand.dampingCollapse
    property real rDamping: Services.Motion.islandExpand.dampingCollapse

    onTargetWChanged: wDamping = (targetW + earRadius * 2 > width)
        ? Services.Motion.islandExpand.dampingExpand
        : Services.Motion.islandExpand.dampingCollapse
    onTargetHChanged: hDamping = (targetH > height)
        ? Services.Motion.islandExpand.dampingExpand
        : Services.Motion.islandExpand.dampingCollapse
    onTargetRChanged: rDamping = (targetR > bodyRadius)
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

    // Passive hover tracking for the collapsed island geometry.
    HoverHandler {
        id: hoverHandler
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
        x: bodyRect.x - earRadius
        y: 0
        width: earRadius
        height: earRadius
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

        // --- Collapsed content: center widgets or fallback clock ---
        Item {
            id: collapsedContent
            anchors.fill: parent
            opacity: Services.IslandService.expanded ? 0 : 1
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Switch collapsed content between the real center widgets and the fallback clock.
            Loader {
                id: collapsedContentLoader

                anchors.centerIn: parent
                sourceComponent: root.showManagedCenterWidgets ? managedCenterWidgets : fallbackClock
            }

            // Render the actual managed center widgets in collapsed mode.
            Component {
                id: managedCenterWidgets

                Row {
                    id: centerWidgetsRow

                    spacing: 8

                    Repeater {
                        model: root.centerWidgets.length

                        Bar.BarWidgetWrapper {
                            required property int index

                            screenName: root.screenName
                            widgetEntry: root.centerWidgets[index]
                            widgetSource: Qt.resolvedUrl(widgetEntry.source)
                        }
                    }
                }
            }

            // Keep the clock as the fallback when no center widgets exist.
            Component {
                id: fallbackClock

                IslandClock {
                }
            }
        }

        // --- Expanded content: search + results ---
        Item {
            id: expandedContent
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 12
            opacity: Services.IslandService.expanded ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            IslandLauncher {
                anchors.fill: parent
                visible: parent.visible
            }
        }

        // Keep left-click expansion on the whole collapsed island surface.
        MouseArea {
            anchors.fill: parent
            enabled: !Services.IslandService.expanded
                && !Services.BarLayoutService.settingsMode
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: Services.IslandService.toggle()
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

    // Right-click opens the center layout menu across the collapsed island.
    MouseArea {
        anchors.fill: parent
        enabled: !Services.IslandService.expanded && !root.showManagedCenterWidgets
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            var scenePos = root.mapToItem(null, mouse.x, mouse.y)
            Services.BarLayoutService.openContextMenu(scenePos.x, "", "")
        }
    }

    // --- Right ear geometry (connects body to screen top-right) ---
    // Geometry-only marker: positions the blur strips and the silhouette path.
    Item {
        id: rightEar
        x: bodyRect.x + bodyRect.width
        y: 0
        width: earRadius
        height: earRadius
        visible: root.height > 0
    }
}
