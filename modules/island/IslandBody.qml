import QtQuick
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

    onSurfaceColorChanged: {
        bodyFill.requestPaint()
        leftEar.requestPaint()
        rightEar.requestPaint()
    }

    onBodyRadiusChanged: bodyFill.requestPaint()

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

    // Blur source parts for the center island body and top ears.
    readonly property var blurParts: [
        {
            item: bodyBlurInset,
            radius: Math.max(0, root.bodyRadius - Services.SettingsService.blurRegionInset),
            topLeftRadius: 0,
            topRightRadius: 0,
            bottomLeftRadius: Math.max(0, root.bodyRadius - Services.SettingsService.blurRegionInset),
            bottomRightRadius: Math.max(0, root.bodyRadius - Services.SettingsService.blurRegionInset)
        }
    ].concat(
        root._stripParts(leftEarBlurStrips, leftEar.visible),
        root._stripParts(rightEarBlurStrips, rightEar.visible)
    )

    // Forward widget-aware context menu requests from center widget wrappers.
    function openWidgetContextMenu(instanceKey, widgetId, clickX) {
        Services.BarLayoutService.openContextMenu(clickX, instanceKey, widgetId)
    }

    // SpringAnimation for organic feel (reference project values).
    Behavior on width {
        SpringAnimation {
            spring: Services.Motion.hover.spring
            mass: Services.Motion.hover.mass
            damping: Services.Motion.hover.damping
            epsilon: Services.Motion.hover.epsilon
        }
    }
    Behavior on height {
        SpringAnimation {
            spring: Services.Motion.hover.spring
            mass: Services.Motion.hover.mass
            damping: Services.Motion.hover.damping
            epsilon: Services.Motion.hover.epsilon
        }
    }
    Behavior on bodyRadius {
        SpringAnimation {
            spring: Services.Motion.hover.spring
            mass: Services.Motion.hover.mass
            damping: Services.Motion.hover.damping
            epsilon: Services.Motion.hover.epsilon
        }
    }

    // Passive hover tracking for the collapsed island geometry.
    HoverHandler {
        id: hoverHandler
    }

    // --- Left ear (connects body to screen top-left) ---
    Canvas {
        id: leftEar
        x: bodyRect.x - earRadius
        y: 0
        width: earRadius
        height: earRadius
        antialiasing: true
        visible: root.height > 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = root.surfaceColor
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
            ctx.closePath()
            ctx.fill()
        }

        Connections {
            target: Services.Color
            function onMSurfaceChanged() { leftEar.requestPaint() }
        }
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
    Item {
        id: bodyRect
        x: root.earRadius
        y: 0
        width: root.width - root.earRadius * 2
        height: root.height
        clip: true

        // Paint the center body in one pass so semi-transparent fill does not self-overlap.
        Canvas {
            id: bodyFill

            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height
                var radius = Math.min(root.bodyRadius, w / 2, h / 2)

                ctx.clearRect(0, 0, w, h)
                ctx.fillStyle = root.surfaceColor
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(w, 0)
                ctx.lineTo(w, h - radius)
                ctx.quadraticCurveTo(w, h, w - radius, h)
                ctx.lineTo(radius, h)
                ctx.quadraticCurveTo(0, h, 0, h - radius)
                ctx.closePath()
                ctx.fill()
            }

            onHeightChanged: requestPaint()
            onWidthChanged: requestPaint()
        }

        Item {
            id: bodyBlurInset

            anchors.fill: parent
            anchors.margins: Services.SettingsService.blurRegionInset
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

    // --- Right ear (connects body to screen top-right) ---
    Canvas {
        id: rightEar
        x: bodyRect.x + bodyRect.width
        y: 0
        width: earRadius
        height: earRadius
        antialiasing: true
        visible: root.height > 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = root.surfaceColor
            ctx.beginPath()
            ctx.moveTo(width, 0)
            ctx.lineTo(0, 0)
            ctx.lineTo(0, height)
            ctx.arc(width, height, width, Math.PI, Math.PI * 1.5, false)
            ctx.closePath()
            ctx.fill()
        }

        Connections {
            target: Services.Color
            function onMSurfaceChanged() { rightEar.requestPaint() }
        }
    }
}
