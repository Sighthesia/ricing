import "." as Widgets
import QtQuick
import "../../../services" as Services

// Brightness indicator with scroll-to-adjust.
Item {
    id: root

    property real dockzoneRevealCenterX: -1
    property real dockzoneRevealTargetCenterX: -1
    property real dockzoneRevealViewportWidth: -1
    property real dockzoneActualExpandHeight: 0
    // Fixed detail viewport hover from the section-level hit target.
    property bool detailViewportHovered: false
    readonly property real dockzoneExpandHeight: brightnessBadge.dockzoneExpandHeight
    readonly property real dockzoneExpandWidth: brightnessBadge.dockzoneExpandWidth
    readonly property bool badgeActive: brightnessBadge.pointerActive
    readonly property bool badgeContainsMouse: brightnessBadge.badgeContainsMouse

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
        dockzoneRevealCenterX: root.dockzoneRevealCenterX
        dockzoneRevealTargetCenterX: root.dockzoneRevealTargetCenterX
        dockzoneRevealViewportWidth: root.dockzoneRevealViewportWidth
        dockzoneActualExpandHeight: root.dockzoneActualExpandHeight
        detailViewportHovered: root.detailViewportHovered
        progressValue: Services.BrightnessService.brightness
        progressColor: Services.Color.mPrimary
        onWheel: event => {
            let step = Services.SettingsService.controls.brightnessStep
            let delta = event.angleDelta.y > 0 ? step : -step
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
