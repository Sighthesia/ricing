import QtQuick
import "../../services" as Services

// Host a managed bar widget with shared section sizing, drag support, and layout editing.
Item {
    id: root

    required property var widgetEntry
    required property string widgetSource
    required property string screenName
    property real availableWidth: -1
    property real dockzoneRevealCenterX: -1
    property real dockzoneRevealTargetCenterX: -1
    property real dockzoneRevealViewportWidth: -1
    // Host's spring-applied actual expand height, for deriving in-phase reveal.
    property real dockzoneActualExpandHeight: 0
    // Active-detail tracking: BarSection sets this to the currently active widget's key.
    // Only the matching wrapper forwards dockzoneActualExpandHeight to its widget.
    property string activeDetailKey: ""
    // Section-level fixed detail viewport hover state. Forwarded to the loaded
    // widget so its CircularHoverWidget can gate detail viewport hover with
    // dockzoneActualExpandHeight > 0 (active owner check).
    property bool detailViewportHovered: false
    // Bound from the loaded widget's badgeActive when the widget exposes it.
    property bool badgeActive: false
    // Badge-only hover — obsolete with stable hit-layer architecture.
    // Kept as property to avoid breaking external readers.
    property bool badgeContainsMouse: false
    readonly property string widgetInstanceKey: widgetEntry && widgetEntry.instanceKey ? widgetEntry.instanceKey : ""
    readonly property string widgetId: widgetEntry && widgetEntry.id ? widgetEntry.id : ""
    readonly property bool isActiveDetailOwner: root.widgetInstanceKey.length > 0 && root.activeDetailKey === root.widgetInstanceKey
    // Only the active detail owner may consume the host's actual expand height for reveal.
    // All other widgets see 0 so their details stay hidden even while the host is expanded.
    readonly property real gatedActualExpandHeight: root.isActiveDetailOwner ? root.dockzoneActualExpandHeight : 0
    readonly property real dockzoneExpandHeight: root._dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: root._dockzoneExpandWidth
    readonly property bool localPointerIntent: pointerHover.hovered
    readonly property real centerXInRoot: width > 0 ? mapToItem(null, width / 2, height / 2).x : 0
    property real _dockzoneExpandHeight: 0
    property real _dockzoneExpandWidth: 0
    objectName: widgetInstanceKey

    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    implicitWidth: _isDragging ? 0 : (loader.item ? loader.item.implicitWidth : 0)
    width: implicitWidth
    height: implicitHeight

    // Collapse width during drag so the Row reflows without this widget.
    readonly property bool _isDragging:
        Services.BarLayoutService.isDragging
        && Services.BarLayoutService.draggedInstanceKey === root.widgetInstanceKey

    Behavior on implicitWidth {
        enabled: root._isDragging
        NumberAnimation { duration: Services.Motion.number.settleDuration; easing.type: Services.Motion.number.settleEasing }
    }

    // --- Settings mode visual outline ---
    Rectangle {
        id: settingsOutline

        anchors.fill: parent
        anchors.margins: -2
        radius: 6
        color: "transparent"
        border.color: "#66ffffff"
        border.width: Services.BarLayoutService.settingsMode && !root._isDragging ? 1 : 0
        opacity: Services.BarLayoutService.settingsMode && !root._isDragging ? 0.6 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Services.Motion.number.settleDuration; easing.type: Services.Motion.number.settleEasing }
        }
    }

    // --- Remove button in settings mode ---
    Rectangle {
        id: removeButton

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -4
        anchors.rightMargin: -4
        width: 16
        height: 16
        radius: 8
        color: removeArea.containsMouse ? "#ff4444" : "#aa333333"
        border.color: "#66ffffff"
        border.width: 1
        opacity: Services.BarLayoutService.settingsMode && !root._isDragging ? 1 : 0
        visible: opacity > 0
        z: 10

        Behavior on opacity {
            NumberAnimation { duration: Services.Motion.number.settleDuration; easing.type: Services.Motion.number.settleEasing }
        }

        Services.FluidText {
            anchors.centerIn: parent
            text: "\u00d7"
            color: "white"
            basePixelSize: 10
            font.bold: true
        }

        MouseArea {
            id: removeArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Services.BarLayoutService.removeWidget(root.widgetInstanceKey)
        }
    }

    // --- Widget content loader ---
    Loader {
        id: loader

        anchors.centerIn: parent
        source: Qt.resolvedUrl(root.widgetSource)
        visible: !root._isDragging

        onLoaded: {
            if (!item)
                return

            if (item.widgetInstanceKey !== undefined)
                item.widgetInstanceKey = root.widgetInstanceKey

            if (item.widgetId !== undefined)
                item.widgetId = root.widgetId

            if (item.availableWidth !== undefined)
                item.availableWidth = Qt.binding(function() { return root.availableWidth })

            if (item.dockzoneRevealCenterX !== undefined)
                item.dockzoneRevealCenterX = Qt.binding(function() { return root.dockzoneRevealCenterX })

            if (item.dockzoneRevealTargetCenterX !== undefined)
                item.dockzoneRevealTargetCenterX = Qt.binding(function() { return root.dockzoneRevealTargetCenterX })

            if (item.dockzoneRevealViewportWidth !== undefined)
                item.dockzoneRevealViewportWidth = Qt.binding(function() { return root.dockzoneRevealViewportWidth })

            if (item.dockzoneActualExpandHeight !== undefined)
                item.dockzoneActualExpandHeight = Qt.binding(function() { return root.gatedActualExpandHeight })

            if (item.detailViewportHovered !== undefined)
                item.detailViewportHovered = Qt.binding(function() { return root.detailViewportHovered })

            if (item.badgeActive !== undefined)
                root.badgeActive = Qt.binding(function() { return item.badgeActive })

            if (item.badgeContainsMouse !== undefined)
                root.badgeContainsMouse = Qt.binding(function() { return item.badgeContainsMouse })

            root._dockzoneExpandHeight = item.dockzoneExpandHeight !== undefined
                ? item.dockzoneExpandHeight
                : 0
            root._dockzoneExpandWidth = item.dockzoneExpandWidth !== undefined
                ? item.dockzoneExpandWidth
                : 0
        }
    }

    Connections {
        target: loader.item
        ignoreUnknownSignals: true

        function onDockzoneExpandHeightChanged() {
            root._dockzoneExpandHeight = loader.item && loader.item.dockzoneExpandHeight !== undefined
                ? loader.item.dockzoneExpandHeight
                : 0
        }

        function onDockzoneExpandWidthChanged() {
            root._dockzoneExpandWidth = loader.item && loader.item.dockzoneExpandWidth !== undefined
                ? loader.item.dockzoneExpandWidth
                : 0
        }
    }

    // Passive right-click + hover detection via pointer handlers so they do not
    // consume hover events that inner widgets (e.g. Tray icons) rely on.
    HoverHandler {
        id: pointerHover
    }

    TapHandler {
        id: pointerArea

        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint) => {
            // Forward right-click to BarContent's context menu with widget context.
            var scenePos = root.mapToItem(null, eventPoint.position.x, eventPoint.position.y)
            var barContent = root.parent
            while (barContent && !barContent.openWidgetContextMenu) {
                barContent = barContent.parent
            }
            if (barContent && barContent.openWidgetContextMenu) {
                barContent.openWidgetContextMenu(root.widgetInstanceKey, root.widgetId, scenePos.x, root.screenName, root.centerXInRoot)
            }
        }
    }

    // --- Drag support (only in settings mode) ---
    HoverHandler {
        enabled: Services.BarLayoutService.settingsMode
        cursorShape: root._isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    DragHandler {
        id: dragHandler

        enabled: Services.BarLayoutService.settingsMode
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        property real startSceneX: 0

        onActiveChanged: {
            if (active) {
                startSceneX = centroid.scenePosition.x
                Services.BarLayoutService.beginDrag(
                    root.widgetInstanceKey,
                    root.widgetId,
                    centroid.scenePosition.x
                )
            } else {
                Services.BarLayoutService.endDrag()
            }
        }

        onCentroidChanged: {
            if (active) {
                Services.BarLayoutService.updateDrag(centroid.scenePosition.x)
            }
        }
    }

}
