import QtQuick
import "../../../services" as Services

// Rolling digit strip used by clock surfaces to animate number changes.
Item {
    id: root

    property int targetDigit: 0
    property color digitColor: Services.Color.mOnSurface
    property color mutedDigitColor: Services.Color.mOnSurfaceVariant
    property int digitPixelSize: Services.TextSize.barContent
    property real digitScale: 1.0
    property string digitFontFamily: ""

    readonly property int digitHeight: Math.max(1, Math.round(root.digitPixelSize * 1.35))
    readonly property int digitWidth: Math.max(1, Math.ceil(_digitMetrics.advanceWidth))

    width: digitWidth
    height: digitHeight
    clip: true

    TextMetrics {
        id: _digitMetrics
        text: "8"
        font.family: root.digitFontFamily || Services.SettingsService.appearance.fontDefault || Qt.application.font.family
        font.pixelSize: Math.round(root.digitPixelSize * root.digitScale)
    }

    property real _displayDigit: root.targetDigit

    onTargetDigitChanged: _displayDigit = root.targetDigit

    Behavior on _displayDigit {
        NumberAnimation {
            duration: 180
            easing.type: Easing.InOutCubic
        }
    }

    Repeater {
        model: 10

        Services.FluidText {
            width: root.width
            height: root.digitHeight
            y: index * root.digitHeight - root._displayDigit * root.digitHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: index.toString()
            color: index === root.targetDigit ? root.digitColor : root.mutedDigitColor
            basePixelSize: root.digitPixelSize
            explicitFontFamily: root.digitFontFamily
            font.bold: true
        }
    }
}
