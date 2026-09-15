import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Square brightness: wheel steps, level shown as rounded horizontal bar below icon.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property real level: Math.max(0, Math.min(1, Services.BrightnessService.brightness))
    // Last discrete step that already flashed; -1 until first paint.
    property int _lastFlashStep: -1

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: true

    implicitWidth: LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = Math.round(root.level * 100) + "%"
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: "Brightness",
            iconSource: Qt.resolvedUrl("../icons/brightness.svg"),
            tintIcon: true,
            summary: summaryText,
            actionKind: "brightness",
            anchorX: centerX,
            payload: {
                brightness: Services.BrightnessService.brightness,
                brightnessService: Services.BrightnessService,
                onBrightnessChanged: function(v) { Services.BrightnessService.setBrightness(v) }
            }
        }
    }

    onHoveredChanged: {
        if (hovered) popupRequested(buildHoverIntent())
        else popupCloseRequested()
    }

    onXChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())

    // Flash the bottom level bar once per discrete step, mirroring slider ticks.
    onLevelChanged: root._noteLiveStep()

    function _noteLiveStep() {
        var step = Math.round(root.level * 100)
        if (root._lastFlashStep < 0) {
            root._lastFlashStep = step
            return
        }
        if (step === root._lastFlashStep)
            return
        root._lastFlashStep = step
        if (!MotionTokens.reducedMotion)
            levelFlashAnimation.restart()
    }

    WheelHandler {
        objectName: "brightnessWheelHandler"
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
    // Scheme-aware glyph (dark in light mode, white in dark mode).
    BarIcon {
        id: brightnessIcon

        anchors.centerIn: parent
        width: LazerTheme.barGlyphSize - 4
        height: LazerTheme.barGlyphSize - 4
        source: Qt.resolvedUrl("../icons/brightness.svg")
        opacity: 0.9
    }

    // Rounded horizontal level bar below the icon, replacing the percentage text.
    Rectangle {
        id: brightnessTrack

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: brightnessIcon.bottom
        anchors.topMargin: 4
        width: LazerTheme.barWidgetHeight - 16
        height: LazerTheme.barIndicatorHeight
        radius: LazerTheme.barIndicatorRadius
        color: Qt.rgba(1, 1, 1, 0.14)
        clip: true

        Rectangle {
            id: brightnessFill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.level
            radius: LazerTheme.barIndicatorRadius
            color: LazerTheme.accentColor

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
            }
        }

        // Tick wash follows the travelled fill; non-interactive visual layer.
        Rectangle {
            id: levelFlash
            anchors.fill: brightnessFill
            radius: LazerTheme.barIndicatorRadius
            color: LazerTheme.flashWash
            opacity: 0

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }

    // Shared tick flash: white-equivalent wash fading with OutQuint.
    NumberAnimation {
        id: levelFlashAnimation
        target: levelFlash
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
        running: false
    }

    // Keep the wash dark when reduced motion is toggled mid-flight.
    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion) {
                levelFlashAnimation.stop()
                levelFlash.opacity = 0
            }
        }
    }

}
