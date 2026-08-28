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

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: true

    onClicked: Services.VolumeService.toggleSinkMute()

    implicitWidth: LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = root.muted ? "Muted \u00B7 " + Math.round(root.level * 100) + "%" : Math.round(root.level * 100) + "%"
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: "Volume",
            iconSource: Qt.resolvedUrl("../icons/volume.svg"),
            summary: summaryText,
            actionKind: "volume",
            anchorX: centerX,
            payload: {
                volume: Services.VolumeService.sinkVolume,
                muted: Services.VolumeService.sinkMuted,
                volumeService: Services.VolumeService,
                onVolumeChanged: function(v) { Services.VolumeService.setSinkVolume(v) },
                onToggleMute: function() { Services.VolumeService.toggleSinkMute() }
            }
        }
    }

    onHoveredChanged: {
        if (hovered) popupRequested(buildHoverIntent())
        else popupCloseRequested()
    }

    // Update anchor while the bar layout moves.
    onXChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())

    WheelHandler {
        objectName: "volumeWheelHandler"
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
        source: Qt.resolvedUrl("../icons/volume.svg")
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

}
