import "." as Widgets
import QtQuick
import "../../../services" as Services

// Volume indicator with scroll-to-adjust and click-to-mute.
Item {
    id: root

    readonly property real displayVolume: Services.VolumeService.sinkMuted ? 0 : Services.VolumeService.sinkVolume
    readonly property color accentColor: Services.VolumeService.sinkMuted
        ? Services.Color.mError
        : Services.Color.mPrimary

    implicitWidth: volumeBadge.implicitWidth
    implicitHeight: 30

    // Render the circular volume badge and expand the percentage on hover.
    Widgets.CircularHoverWidget {
        id: volumeBadge

        anchors.centerIn: parent
        clickable: true
        centerText: Services.VolumeService.sinkMuted ? "\uf6a9" : "\uf028"
        centerTextFontFamily: "Symbols Nerd Font"
        centerTextPixelSize: 10
        centerTextColor: root.accentColor
        progressValue: root.displayVolume
        progressColor: root.accentColor
        onActivated: Services.VolumeService.toggleSinkMute()
        onWheel: event => {
            let delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            Services.VolumeService.setSinkVolume(Services.VolumeService.sinkVolume + delta)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Services.VolumeService.sinkMuted ? "Muted" : (Math.round(Services.VolumeService.sinkVolume * 100) + "%")
            color: Services.VolumeService.sinkMuted
                ? Services.Color.mError
                : Services.Color.mOnSurface
            font.pixelSize: Services.TextSize.barContent
        }
    }
}
