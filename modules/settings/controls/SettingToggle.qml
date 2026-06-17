import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../../services" as Services
import "../../bar/MenuVisuals.js" as MenuVisuals

// A labeled toggle row binding a boolean setting to a Switch.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property bool checked: false
    property bool filterVisible: true
    property real contentInset: MenuVisuals.contentInset

    signal toggled(bool value)

    width: Math.max(0, parent.width - root.contentInset * 2)
    x: root.contentInset + (filterVisible ? 0 : 24)
    height: filterVisible ? implicitHeight : 0
    spacing: MenuVisuals.contentSpacing
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
        width: parent.width - toggle.width - parent.spacing - root.contentInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: MenuVisuals.compactSpacing

        Services.FluidText {
            width: parent.width
            text: root.settingLabel
            color: Services.Color.mOnSurface
            basePixelSize: MenuVisuals.bodyFontSize
        }

        Services.FluidText {
            width: parent.width
            text: root.description
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 10
            visible: root.description !== ""
            wrapMode: Text.WordWrap
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
