import QtQuick
import QtQuick.Controls
import "../../../services" as Services

// A labeled dropdown row for enum/string settings.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property var model: []
    property string currentValue: ""

    signal selected(string value)

    width: parent.width
    spacing: 8

    // Label and description on the left
    Column {
        width: parent.width - combo.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: root.settingLabel
            color: Services.Color.mOnSurface
            font.pixelSize: 13
        }

        Text {
            text: root.description
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: 11
            visible: root.description !== ""
        }
    }

    // Dropdown on the right
    ComboBox {
        id: combo
        anchors.verticalCenter: parent.verticalCenter
        model: root.model
        width: 140
        currentIndex: root.model.indexOf(root.currentValue)
        onActivated: root.selected(root.model[currentIndex])
    }
}
