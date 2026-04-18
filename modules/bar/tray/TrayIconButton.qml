import Quickshell
import QtQuick
import qs.config
import "../" as BarComponents

// Interactive tray icon surface with upstream activation, menu, and wheel hooks.
Item {
    id: root

    required property var item
    required property QtObject menuParent
    required property var menuController

    property bool middleClickEnabled: false
    property bool wheelEnabled: true
    property int buttonSize: Math.max(1, Theme.barWidget.pillHeight - Theme.barWidget.contentPaddingV * 2)
    property int iconSize: Theme.barWidget.primaryIconSize

    readonly property string _iconSource: {
        if (root.item && root.item.icon)
            return root.item.icon
        return Quickshell.iconPath("application-x-executable")
    }

    function _requestTrayMenu(mouse) {
        if (!root.item || !root.item.hasMenu || !root.menuController)
            return

        const anchorPoint = root.mapToItem(root.menuParent, mouse.x, mouse.y)
        root.menuController.showForItem(root.item, Math.round(anchorPoint.x), Math.round(anchorPoint.y))
    }

    implicitWidth: root.buttonSize
    implicitHeight: root.buttonSize

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Colors.surface
        border.color: Colors.border
        border.width: 1
    }

    BarComponents.HoverRevealHighlight {
        anchors.fill: parent
        hovered: area.containsMouse
        radius: width / 2
        adaptiveContrast: true
        surfaceColor: Colors.surface
    }

    Image {
        anchors.centerIn: parent
        source: root._iconSource
        width: root.iconSize
        height: root.iconSize
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        smooth: true
        fillMode: Image.PreserveAspectFit
    }

    BarComponents.ClickRipple {
        id: ripple

        anchors.fill: parent
        radius: width / 2
    }

    MouseArea {
        id: area

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            ripple.triggerRipple(mouse.x, mouse.y)

            if (mouse.button === Qt.RightButton) {
                root._requestTrayMenu(mouse)
                return
            }

            if (mouse.button === Qt.MiddleButton) {
                if (root.middleClickEnabled && root.item && typeof root.item.secondaryActivate === "function")
                    root.item.secondaryActivate()
                return
            }

            if (!root.item)
                return

            if (root.item.onlyMenu && root.item.hasMenu && root.menuController) {
                root._requestTrayMenu(mouse)
                return
            }

            if (typeof root.item.activate === "function")
                root.item.activate()
        }
        onWheel: function(wheel) {
            if (!root.wheelEnabled || !root.item || typeof root.item.scroll !== "function")
                return

            const isHorizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
            const delta = isHorizontal ? wheel.angleDelta.x : wheel.angleDelta.y
            if (delta === 0)
                return

            root.item.scroll(delta, isHorizontal)
            wheel.accepted = true
        }
    }
}
