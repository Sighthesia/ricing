import QtQuick
import "../../../services" as Services

// Volume indicator with scroll-to-adjust and click-to-mute.
Item {
    id: root

    implicitWidth: volumeRow.implicitWidth + 20
    implicitHeight: 30

    WheelHandler {
        onWheel: event => {
            let delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            Services.VolumeService.setSinkVolume(Services.VolumeService.sinkVolume + delta)
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Services.VolumeService.toggleSinkMute()
    }

    Row {
        id: volumeRow
        anchors.centerIn: parent
        spacing: 4

        // Volume icon (changes with mute state)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Services.VolumeService.sinkMuted ? "🔇" : "🔊"
            font.pixelSize: 16
            color: Services.Color.mOnSurface
        }

        // Percentage
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Services.VolumeService.sinkVolume * 100) + "%"
            color: Services.VolumeService.sinkMuted
                ? Services.Color.mOutline
                : Services.Color.mOnSurfaceVariant
            font.pixelSize: Services.TextSize.barContent
        }
    }
}
