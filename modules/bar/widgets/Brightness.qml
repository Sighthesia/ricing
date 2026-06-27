import "." as Widgets
import QtQuick
import "../../../services" as Services

// Brightness indicator with scroll-to-adjust.
Item {
    id: root

    readonly property real dockzoneExpandHeight: brightnessBadge.dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: brightnessBadge.dockzoneExpandWidth

    implicitWidth: brightnessBadge.implicitWidth
    implicitHeight: 30

    // Render the circular brightness badge and reveal percentage below the dockzone.
    Widgets.CircularHoverWidget {
        id: brightnessBadge

        anchors.centerIn: parent
        centerText: "\uf185"
        centerTextFontFamily: "Symbols Nerd Font"
        centerTextPixelSize: 10
        centerTextColor: Services.Color.mPrimary
        progressValue: Services.BrightnessService.brightness
        progressColor: Services.Color.mPrimary
        onWheel: event => {
            let delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            Services.BrightnessService.setBrightness(Services.BrightnessService.brightness + delta)
        }

        Widgets.CompactHoverDetail {
            iconText: "\uf185"
            labelText: "Brightness"
            valueText: Math.round(Services.BrightnessService.brightness * 100) + "%"
            progressValue: Services.BrightnessService.brightness
            accentColor: Services.Color.mPrimary
            interactive: true
            onMoved: value => Services.BrightnessService.setBrightness(value)
        }
    }
}
