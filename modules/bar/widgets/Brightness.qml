import QtQuick
import "../../lazerbar"
import "../../../services" as Services

// Square brightness: wheel steps, level shown as rounded horizontal bar below icon.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property real level: Math.max(0, Math.min(1, Services.BrightnessService.brightness))

    implicitWidth: LazerTheme.barWidgetHeight
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

    // Icon stays vertically centered; progress sits directly below it.
    Image {
        id: brightnessIcon

        anchors.centerIn: parent
        width: LazerTheme.barGlyphSize - 4
        height: LazerTheme.barGlyphSize - 4
        source: "../icons/brightness.svg"
        opacity: 0.9
    }

    // Rounded horizontal level bar below the icon, replacing the percentage text.
    Rectangle {
        id: brightnessTrack

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: brightnessIcon.bottom
        anchors.topMargin: 4
        width: LazerTheme.barWidgetHeight - 16
        height: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.14)
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.level
            radius: 1.5
            color: LazerTheme.textPrimary

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
            }
        }
    }
}
