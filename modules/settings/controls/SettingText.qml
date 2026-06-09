import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../../services" as Services

// A labeled text-input row for free-form string settings.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property string text: ""
    property string placeholderText: ""
    property bool filterVisible: true

    signal edited(string value)

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
