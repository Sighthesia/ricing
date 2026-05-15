import QtQuick
import "../../../services" as Services

// Brightness indicator with scroll-to-adjust.
Item {
    id: root

    implicitWidth: brightnessRow.implicitWidth + 16
    implicitHeight: 26

    WheelHandler {
        onWheel: event => {
            let delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            Services.BrightnessService.setBrightness(Services.BrightnessService.brightness + delta)
        }
    }

    Row {
        id: brightnessRow
        anchors.centerIn: parent
        spacing: 4

        // Sun icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "☀"
            font.pixelSize: 14
            color: Services.Color.mOnSurface
        }

        // Percentage
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Services.BrightnessService.brightness * 100) + "%"
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: 11
        }
    }
}
