import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../../services" as Services

// A labeled toggle row binding a boolean setting to a Switch.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property bool checked: false
    property bool filterVisible: true

    signal toggled(bool value)

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
        width: parent.width - toggle.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Services.FluidText {
            text: root.settingLabel
            color: Services.Color.mOnSurface
            basePixelSize: 13
        }

        Services.FluidText {
            text: root.description
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 11
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
