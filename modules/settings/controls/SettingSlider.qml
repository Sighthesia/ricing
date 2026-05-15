import QtQuick
import QtQuick.Controls
import "../../../services" as Services

// A labeled slider row for numeric settings with optional unit suffix.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string suffix: ""

    signal moved(real value)

    width: parent.width
    spacing: 8

    // Label and description on the left
    Column {
        width: parent.width - controlRow.width - parent.spacing
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

    // Slider and value display on the right
    Row {
        id: controlRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Slider {
            id: slider
            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value
            width: 120
            anchors.verticalCenter: parent.verticalCenter
            onMoved: root.moved(value)
        }

        // Formatted value label
        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Show integers without decimals, reals to 2dp
            text: (root.stepSize < 1 ? slider.value.toFixed(2) : Math.round(slider.value).toString()) + root.suffix
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: 11
            width: 48
        }
    }
}
