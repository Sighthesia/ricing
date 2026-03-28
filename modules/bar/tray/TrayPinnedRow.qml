import Quickshell
import QtQuick
import qs.config
import "." as TrayComponents

// Main-pill tray row for pinned icons and the minimal empty anchor surface.
Item {
    id: root

    required property var items
    required property QtObject menuParent
    required property var menuController

    property bool showEmptyAnchor: false

    readonly property int _buttonSize: Theme.barWidget.pillHeight
    readonly property int _spacing: Theme.barWidget.iconSpacing

    implicitWidth: root.items.length > 0 ? iconRow.implicitWidth : (root.showEmptyAnchor ? emptyAnchor.width : 0)
    implicitHeight: root._buttonSize

    Row {
        id: iconRow

        visible: root.items.length > 0
        spacing: root._spacing

        Repeater {
            model: root.items

            delegate: TrayComponents.TrayIconButton {
                required property var modelData

                item: modelData
                menuParent: root.menuParent
                menuController: root.menuController
                buttonSize: root._buttonSize
            }
        }
    }

    Rectangle {
        id: emptyAnchor

        visible: root.items.length === 0 && root.showEmptyAnchor
        width: root._buttonSize
        height: root._buttonSize
        radius: width / 2
        color: Colors.surface
        border.color: Colors.border
        border.width: 1

        Image {
            anchors.centerIn: parent
            source: Quickshell.iconPath("preferences-system-windows", "application-x-executable")
            width: Theme.barWidget.primaryIconSize
            height: Theme.barWidget.primaryIconSize
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            fillMode: Image.PreserveAspectFit
        }
    }
}
