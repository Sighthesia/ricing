import QtQuick
import QtQuick.Controls
import "../../../services" as Services

// A labeled text-input row for free-form string settings.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property string text: ""
    property string placeholderText: ""

    signal edited(string value)

    width: parent.width
    spacing: 8

    // Label and description on the left
    Column {
        width: parent.width - field.width - parent.spacing
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

    // Text input on the right
    TextField {
        id: field
        anchors.verticalCenter: parent.verticalCenter
        width: 160
        text: root.text
        placeholderText: root.placeholderText
        onEditingFinished: root.edited(text)
    }
}
