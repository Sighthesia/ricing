import QtQuick
import qs.config
import "." as TrayComponents

// Flash-strip tray row for non-pinned icons with a terminal +N overflow chip.
Item {
    id: root

    required property var items
    required property QtObject menuParent

    property int maxStripWidth: 0

    readonly property int _buttonSize: Theme.barWidget.pillHeight
    readonly property int _spacing: Theme.barWidget.iconSpacing
    readonly property int _slotWidth: root._buttonSize + root._spacing
    readonly property int _capacity: {
        if (root.maxStripWidth <= 0)
            return 0
        return Math.max(1, Math.floor((root.maxStripWidth + root._spacing) / root._slotWidth))
    }
    readonly property int _visibleCount: {
        if (root.items.length <= root._capacity)
            return root.items.length
        return Math.max(0, root._capacity - 1)
    }
    readonly property int _hiddenCount: Math.max(0, root.items.length - root._visibleCount)
    readonly property var _visibleItems: root.items.slice(0, root._visibleCount)

    implicitWidth: flashRow.implicitWidth
    implicitHeight: root._buttonSize

    Row {
        id: flashRow

        spacing: root._spacing

        Repeater {
            model: root._visibleItems

            delegate: TrayComponents.TrayIconButton {
                required property var modelData

                item: modelData
                menuParent: root.menuParent
                buttonSize: root._buttonSize
            }
        }

        Rectangle {
            visible: root._hiddenCount > 0
            width: root._buttonSize
            height: root._buttonSize
            radius: width / 2
            color: Colors.surface
            border.color: Colors.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "+" + root._hiddenCount
                color: Colors.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
