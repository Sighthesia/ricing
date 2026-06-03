import QtQuick
import "../../services" as Services

// Host a managed bar widget with shared section sizing, drag support, and layout editing.
Item {
    id: root

    required property var widgetEntry
    required property string widgetSource
    required property string screenName

    readonly property string widgetInstanceKey: widgetEntry && widgetEntry.instanceKey ? widgetEntry.instanceKey : ""
    readonly property string widgetId: widgetEntry && widgetEntry.id ? widgetEntry.id : ""
    readonly property bool localPointerIntent: pointerHover.hovered
    readonly property real centerXInRoot: width > 0 ? mapToItem(null, width / 2, height / 2).x : 0
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

        Text {
            anchors.centerIn: parent
            text: "\u00d7"
            color: "white"
            font.pixelSize: 10
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
            var barPos = root.mapToItem(null, eventPoint.position.x, eventPoint.position.y)
            var barContent = root.parent
            while (barContent && !barContent.openWidgetContextMenu) {
                barContent = barContent.parent
            }
            if (barContent && barContent.openWidgetContextMenu) {
                barContent.openWidgetContextMenu(root.widgetInstanceKey, root.widgetId, barPos.x, root.screenName, root.centerXInRoot)
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
