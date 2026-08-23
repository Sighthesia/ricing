import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Output volume pill: click mutes, wheel steps by the configured amount.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property bool muted: Services.VolumeService.sinkMuted
    readonly property int percent: Math.round(Services.VolumeService.sinkVolume * 100)

    onClicked: Services.VolumeService.toggleSinkMute()

    implicitWidth: contentRow.implicitWidth + 12

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

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: LazerTheme.barGlyphSize - 6
            height: LazerTheme.barGlyphSize - 6
            source: "../icons/volume.svg"
            opacity: root.muted ? 0.4 : 0.9

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "静音" : root.percent + "%"
            color: root.muted ? LazerTheme.textMuted : LazerTheme.textPrimary
            font.pixelSize: 12
        }
    }
}
