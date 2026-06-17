import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../../services" as Services
import "../../bar/MenuVisuals.js" as MenuVisuals

// A labeled text-input row for free-form string settings.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property string text: ""
    property string placeholderText: ""
    property bool filterVisible: true
    property real contentInset: MenuVisuals.contentInset

    signal edited(string value)

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
        width: parent.width - field.width - parent.spacing - root.contentInset
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

    // Text input on the right
    TextField {
        id: field
        anchors.verticalCenter: parent.verticalCenter
        width: 152
        text: root.text
        placeholderText: root.placeholderText
        font.pixelSize: 12
        onEditingFinished: root.edited(text)
    }
}
