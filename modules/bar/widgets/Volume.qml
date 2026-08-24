import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Square output volume: click mutes, wheel steps, level shown as rounded horizontal bar below icon.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property bool muted: Services.VolumeService.sinkMuted
    readonly property real level: root.muted ? 0 : Math.max(0, Math.min(1, Services.VolumeService.sinkVolume))

    onClicked: Services.VolumeService.toggleSinkMute()

    implicitWidth: LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            var step = Number(Services.SettingsService.controls.volumeStep) || 0.05
            var delta = event.angleDelta.y > 0 ? step : -step
            var next = Math.max(0, Math.min(1, Services.VolumeService.sinkVolume + delta))
            Services.VolumeService.setSinkVolume(next)
            event.accepted = true
        }
    }

    // Icon stays vertically centered; progress sits directly below it.
    Image {
        id: volumeIcon

        anchors.centerIn: parent
        width: LazerTheme.barGlyphSize - 4
        height: LazerTheme.barGlyphSize - 4
        source: "../icons/volume.svg"
        opacity: root.muted ? 0.4 : 0.9

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Rounded horizontal level bar below the icon, replacing the percentage text.
    Rectangle {
        id: volumeTrack

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: volumeIcon.bottom
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
            color: root.muted ? Qt.rgba(LazerTheme.accentColor.r, LazerTheme.accentColor.g, LazerTheme.accentColor.b, 0.35) : LazerTheme.accentColor

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
            }
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }

    // Hover opens this widget's popup in the shared overlay host.
    WidgetHoverPopup {
        kind: "volume"
    }
}
