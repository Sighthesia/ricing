import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    property bool filterVisible: true

    signal moved(real value)

    width: parent.width
    height: filterVisible ? implicitHeight : 0
    x: filterVisible ? 0 : 24
    spacing: 8
    opacity: filterVisible ? 1 : 0
    visible: height > 1 || opacity > 0.01
    layer.enabled: !filterVisible || opacity < 0.99
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 10
        blur: (1 - root.opacity) * 0.3
    }

    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
    Behavior on x { NumberAnimation { duration: 180; easing.type: root.filterVisible ? Easing.OutCubic : Easing.InCubic } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: root.filterVisible ? Easing.OutCubic : Easing.InCubic } }

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
