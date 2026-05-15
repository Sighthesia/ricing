import QtQuick
import QtQuick.Controls
import "../../../services" as Services

// A labeled toggle row binding a boolean setting to a Switch.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property bool checked: false

    signal toggled(bool value)

    width: parent.width
    spacing: 8

    // Label and description on the left
    Column {
        width: parent.width - toggle.width - parent.spacing
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

    // Toggle control on the right
    Switch {
        id: toggle
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: root.toggled(checked)
    }
}
