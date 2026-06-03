import "." as Widgets
import QtQuick
import "../../../services" as Services

// Brightness indicator with scroll-to-adjust.
Item {
    id: root

    implicitWidth: brightnessBadge.implicitWidth
    implicitHeight: 30

    // Keep scroll-to-adjust active across the full hover-expand footprint.
    WheelHandler {
        onWheel: event => {
            let delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            Services.BrightnessService.setBrightness(Services.BrightnessService.brightness + delta)
        }
    }

    // Render the circular brightness badge and reveal percentage on hover.
    Widgets.CircularHoverWidget {
        id: brightnessBadge

        anchors.centerIn: parent
        centerText: "\uf185"
        centerTextFontFamily: "Symbols Nerd Font"
        centerTextPixelSize: 10
        centerTextColor: Services.Color.mPrimary
        progressValue: Services.BrightnessService.brightness
        progressColor: Services.Color.mPrimary

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Services.BrightnessService.brightness * 100) + "%"
            color: Services.Color.mOnSurface
            font.pixelSize: Services.TextSize.barContent
        }
    }
}
