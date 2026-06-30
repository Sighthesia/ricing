import "." as Widgets
import QtQuick
import Quickshell.Services.Pipewire
import "../../../services" as Services

// Volume indicator with scroll-to-adjust and click-to-mute.
Item {
    id: root

    readonly property real displayVolume: Services.VolumeService.sinkMuted ? 0 : Services.VolumeService.sinkVolume
    readonly property color accentColor: Services.VolumeService.sinkMuted
        ? Services.Color.mError
        : Services.Color.mPrimary
    property real dockzoneRevealCenterX: -1
    property real dockzoneRevealTargetCenterX: -1
    property real dockzoneRevealViewportWidth: -1
    readonly property real dockzoneExpandHeight: volumeBadge.dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: volumeBadge.dockzoneExpandWidth

    implicitWidth: volumeBadge.implicitWidth
    implicitHeight: 30

    // Render the circular volume badge and reveal the percentage below the dockzone.
    Widgets.CircularHoverWidget {
        id: volumeBadge

        anchors.centerIn: parent
        clickable: true
        centerText: Services.VolumeService.sinkMuted ? "\uf6a9" : "\uf028"
        centerTextFontFamily: "Symbols Nerd Font"
        centerTextPixelSize: 10
        centerTextColor: root.accentColor
        dockzoneRevealCenterX: root.dockzoneRevealCenterX
        dockzoneRevealTargetCenterX: root.dockzoneRevealTargetCenterX
        dockzoneRevealViewportWidth: root.dockzoneRevealViewportWidth
        progressValue: root.displayVolume
        progressColor: root.accentColor
        onActivated: Services.VolumeService.toggleSinkMute()
        onWheel: event => {
            let delta = event.angleDelta.y > 0 ? 0.05 : -0.05
            Services.VolumeService.setSinkVolume(Services.VolumeService.sinkVolume + delta)
        }

        Widgets.CompactHoverDetail {
            iconText: Services.VolumeService.sinkMuted ? "\uf6a9" : "\uf028"
            labelText: "Volume"
            valueText: Services.VolumeService.sinkMuted ? "Muted" : (Math.round(Services.VolumeService.sinkVolume * 100) + "%")
            secondaryText: Pipewire.defaultAudioSink ? Services.VolumeService.deviceLabel(Pipewire.defaultAudioSink) : ""
            progressValue: root.displayVolume
            accentColor: root.accentColor
            interactive: true
            onMoved: value => Services.VolumeService.setSinkVolume(value)
        }
    }
}
