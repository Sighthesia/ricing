import QtQuick
import "../../lazerbar"
import "../../../services" as Services

// Screen brightness readout; wheel steps by the configured amount.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property int percent: Math.round(Services.BrightnessService.brightness * 100)

    implicitWidth: contentRow.implicitWidth + 12
    implicitHeight: LazerTheme.barWidgetHeight

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            var step = Number(Services.SettingsService.controls.brightnessStep) || 0.05
            var delta = event.angleDelta.y > 0 ? step : -step
            Services.BrightnessService.setBrightness(
                Math.max(0, Math.min(1, Services.BrightnessService.brightness + delta)))
            event.accepted = true
        }
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: LazerTheme.barGlyphSize - 4
            height: LazerTheme.barGlyphSize - 4
            source: "../icons/brightness.svg"
            opacity: 0.9
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "%"
            color: LazerTheme.textPrimary
            font.pixelSize: 12
        }
    }
}
