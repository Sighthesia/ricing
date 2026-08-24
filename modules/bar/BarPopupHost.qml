import QtQuick
import Quickshell
import "."
import "../lazerbar"
import "../../services" as Services

// Host every hover-driven bar popup in one overlay owner. The outer surface
// stays static per open so per-frame geometry never crosses a costly commit
// boundary; only the inner reveal animates.
Item {
    id: root

    // Live bar metrics shared with the bar window so the popup can dock to
    // the correct edge and share the same horizontal coordinate space.
    property int barHeight: 48
    property bool barTopAnchored: true
    property real floatingMargin: 0

    readonly property bool popupVisible: Services.BarPopupService.visible
    // Frozen copies keep the exiting surface intact during the close reveal.
    property string shownKind: ""
    property var shownPayload: null
    // Anchor snapshot: service.close() zeroes anchorX immediately, and the
    // frame must not chase that zero while fading out.
    property real frameAnchorX: 0
    // The loaded surface, exposed so the window mask can track its bounds.
    readonly property alias activeSurfaceItem: surfaceLoader.item
    onPopupVisibleChanged: {
        if (popupVisible) {
            shownKind = Services.BarPopupService.kind
            shownPayload = Services.BarPopupService.payload
            frameAnchorX = Services.BarPopupService.anchorX
            // osu!lazer popover law: elasticity only for the deform, fades
            // stay smooth.
            fadeAnimation.duration = MotionTokens.slow
            deformAnimation.duration = MotionTokens.popupDeformIn
            deformAnimation.easing.type = Easing.OutElastic
            deformAnimation.easing.amplitude = 0.5
            revealProgress = MotionTokens.reducedMotion ? 1 : 0
            deformProgress = MotionTokens.reducedMotion ? 1 : 0
            fadeAnimation.to = 1
            deformAnimation.to = 1
            fadeAnimation.restart()
            deformAnimation.restart()
        } else {
            fadeAnimation.duration = MotionTokens.slow
            deformAnimation.duration = MotionTokens.slow
            deformAnimation.easing.type = Easing.OutQuint
            fadeAnimation.to = 0
            deformAnimation.to = 0
            fadeAnimation.restart()
            deformAnimation.restart()
            Services.BarPopupService.pointerInPopup = false
        }
    }

    // Opacity rides a smooth curve only; scale and slide share the deform
    // progress that carries the elastic enter settle.
    property real revealProgress: 0
    property real deformProgress: 0

    // Confirm a widget's leave-request once the pointer had a fair chance to
    // travel into the popup surface.
    Timer {
        id: closeGraceTimer

        interval: 240
        onTriggered: {
            if (!Services.BarPopupService.pointerInPopup)
                Services.BarPopupService.close()
            Services.BarPopupService.cancelClose()
        }
    }
    // Any state change that invalidates the pending close stops the timer.
    Connections {
        target: Services.BarPopupService
        function onClosePendingChanged() {
            if (Services.BarPopupService.closePending)
                closeGraceTimer.restart()
            else
                closeGraceTimer.stop()
        }
        function onVisibleChanged() {
            if (!Services.BarPopupService.visible)
                closeGraceTimer.stop()
        }
        // Moving straight between widgets swaps the popup content in place.
        function onKindChanged() {
            if (!Services.BarPopupService.visible)
                return
            root.shownKind = Services.BarPopupService.kind
            root.shownPayload = Services.BarPopupService.payload
            root.frameAnchorX = Services.BarPopupService.anchorX
        }
        // Re-anchoring stays live only while the popup is open, so a close
        // can never drag the fading frame toward the reset-to-zero anchor.
        function onAnchorXChanged() {
            if (Services.BarPopupService.visible)
                root.frameAnchorX = Services.BarPopupService.anchorX
        }
    }

    NumberAnimation {
        id: fadeAnimation

        target: root
        property: "revealProgress"
        easing.type: Easing.OutQuint
    }

    NumberAnimation {
        id: deformAnimation

        target: root
        property: "deformProgress"
    }

    // Pointer presence on the popup keeps the widget-side leave from closing;
    // leaving the popup itself asks for a graceful close.
    HoverHandler {
        enabled: root.popupVisible
        onHoveredChanged: {
            Services.BarPopupService.pointerInPopup = hovered
            if (hovered)
                Services.BarPopupService.cancelClose()
            else
                Services.BarPopupService.requestClose()
        }
    }

    // Escape closes without requiring the pointer to travel back.
    Item {
        anchors.fill: parent
        focus: root.popupVisible
        Keys.onEscapePressed: {
            Services.BarPopupService.close()
            event.accepted = true
        }
    }

    // Content height settles asynchronously (tray menus load their entries
    // late); the declarative frame bindings above track it automatically.

    // Load the popup surface one tick after closing so the exit animation
    // can finish before the content unloads. The loader itself is the popup
    // frame: this Quickshell build stretches a fill-loader's item regardless
    // of the item's own size, so sizing must live here.
    Loader {
        id: surfaceLoader

        active: root.revealProgress > 0 || root.deformProgress > 0
        // Frame geometry is fully declarative: centered on the hover
        // anchor, docked below (or above) the bar, clamped to the screen.
        width: item ? item.implicitWidth : 0
        height: item ? item.implicitHeight : 0
        x: {
            if (!item)
                return 0
            var anchorScreenX = root.frameAnchorX + root.floatingMargin
            return Math.max(8, Math.min(anchorScreenX - width / 2,
                                        root.width - width - 8))
        }
        y: root.barTopAnchored
           ? root.floatingMargin + root.barHeight + 4
           : root.height - root.floatingMargin - root.barHeight - 4 - height
        sourceComponent: {
            switch (root.shownKind) {
            case "tray": return trayMenuComponent
            case "volume": return volumePopupComponent
            case "brightness": return brightnessPopupComponent
            case "clock": return calendarPopupComponent
            case "media": return mediaPopupComponent
            case "notifications": return notificationsPopupComponent
            default: return null
            }
        }

        Component {
            id: trayMenuComponent

            BarTrayMenu { payload: root.shownPayload }
        }

        Component {
            id: volumePopupComponent

            BarSliderPopup {
                title: "Volume"
                iconSource: "icons/volume.svg"
                value: Services.VolumeService.sinkVolume
                showMute: true
                muted: Services.VolumeService.sinkMuted
                onValueModified: value => Services.VolumeService.setSinkVolume(value)
                onMuteToggled: Services.VolumeService.toggleSinkMute()
            }
        }

        Component {
            id: brightnessPopupComponent

            BarSliderPopup {
                title: "Brightness"
                iconSource: "icons/brightness.svg"
                value: Services.BrightnessService.brightness
                onValueModified: value => Services.BrightnessService.setBrightness(value)
            }
        }

        Component {
            id: calendarPopupComponent

            BarCalendarPopup {}
        }

        Component {
            id: mediaPopupComponent

            BarMediaPopup {}
        }

        Component {
            id: notificationsPopupComponent

            BarNotificationsPopup {}
        }
    }

    // Reveal motion stays inside the surface so the overlay window geometry
    // never changes per frame. Enter: the popup starts over the bar and
    // slides down to its dock while scaling up; exit reverses both moves.
    // Travel equals the full dock offset so the surface emerges from the
    // bar's own footprint.
    readonly property real enterTravel: root.floatingMargin + root.barHeight + 4
    transform: [
        Scale {
            origin.x: {
                var surface = surfaceLoader.item
                return surface ? surfaceLoader.x + surfaceLoader.width / 2 : root.width / 2
            }
            origin.y: {
                var surface = surfaceLoader.item
                return surface ? (root.barTopAnchored ? surfaceLoader.y
                                                      : surfaceLoader.y + surfaceLoader.height) : root.height / 2
            }
            xScale: MotionTokens.reducedMotion ? 1 : MotionTokens.popupFromScale + (1 - MotionTokens.popupFromScale) * root.deformProgress
            yScale: MotionTokens.reducedMotion ? 1 : MotionTokens.popupFromScale + (1 - MotionTokens.popupFromScale) * root.deformProgress
        },
        Translate {
            y: MotionTokens.reducedMotion ? 0
               : (root.barTopAnchored ? -1 : 1) * root.enterTravel * (1 - root.deformProgress)
        }
    ]
    opacity: root.revealProgress
}
