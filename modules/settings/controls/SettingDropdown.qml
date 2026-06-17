import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../../services" as Services
import "../../bar/MenuVisuals.js" as MenuVisuals

// A labeled dropdown row for enum/string settings.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property var model: []
    property string currentValue: ""
    property bool filterVisible: true
    property real contentInset: MenuVisuals.contentInset

    signal selected(string value)

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
        width: parent.width - combo.width - parent.spacing - root.contentInset
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

    // Dropdown on the right
    ComboBox {
        id: combo
        anchors.verticalCenter: parent.verticalCenter
        model: root.model
        width: Math.max(108, Math.min(136, root.width * 0.42))
        currentIndex: root.model.indexOf(root.currentValue)
        font.family: Services.SettingsService.appearance.fontDefault || Qt.application.font.family
        font.pixelSize: Math.round(12 * (Services.SettingsService.appearance.fontDefaultScale || 1.0))
        onActivated: root.selected(root.model[currentIndex])

        contentItem: Text {
            text: combo.displayText
            font: combo.font
            color: Services.Color.mOnSurface
            verticalAlignment: Text.AlignVCenter
            leftPadding: MenuVisuals.contentInset
            rightPadding: MenuVisuals.contentInset
        }

        delegate: ItemDelegate {
            width: combo.width
            contentItem: Services.FluidText {
                text: modelData
                color: highlighted ? Services.Color.mPrimary : Services.Color.mOnSurface
                basePixelSize: 12
                verticalAlignment: Text.AlignVCenter
                leftPadding: MenuVisuals.contentInset
            }
            background: Rectangle {
                color: highlighted ? Services.Color.mSurfaceVariant : "transparent"
                radius: 4
            }
        }
    }
}
