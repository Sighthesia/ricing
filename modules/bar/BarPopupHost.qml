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
    // A brand-new loader instance is born at zero geometry; morph must stay
    // off for that single placement tick or the surface visibly flies in
    // from the top-left. Live-instance opens (mid-exit reuse, content swap)
    // keep morphing because the loader already carries real geometry.
    property bool placingSurface: false
    // Frozen copies keep the exiting surface intact during the close reveal.
    property string shownKind: ""
    property var shownPayload: null
    // Anchor snapshot: service.close() zeroes anchorX immediately, and the
    // frame must not chase that zero while fading out.
    property real frameAnchorX: 0
    // The loaded surface, exposed so the window mask can track its bounds.
    readonly property alias activeSurfaceItem: surfaceLoader.item
    // The active surface's floating submenu (tray menus only), so the
    // window's input mask can cover it too.
    readonly property Item submenuSurfaceItem: {
        var surface = surfaceLoader.item
        return surface && surface.submenuSurfaceItem !== undefined
               ? surface.submenuSurfaceItem : null
    }
    // Corridor bridge between the menu and its submenu; covering it keeps
    // gap traversal from registering as a pointer leave.
    readonly property Item submenuBridgeItem: {
        var surface = surfaceLoader.item
        return surface && surface.submenuBridgeItem !== undefined
               ? surface.submenuBridgeItem : null
    }
    onPopupVisibleChanged: {
        if (popupVisible) {
            // Geometry inputs before the content swap: assigning shownKind
            // creates the surface item synchronously, and with morph
            // behaviors live from frame one the item's first binding
            // evaluation must already see the final anchor.
            frameAnchorX = Services.BarPopupService.anchorX
            placingSurface = surfaceLoader.item === null
            placementSettle.start()
            shownKind = Services.BarPopupService.kind
            shownPayload = Services.BarPopupService.payload
            // Settings-panel rhythm: OutQuint over settingsSlide.
            deformAnimation.duration = MotionTokens.reducedMotion ? 0 : MotionTokens.settingsSlide
            deformAnimation.easing.type = Easing.OutQuint
            deformAnimation.to = 1
            // Single-instance reuse: never rewind the deform -- a reopen
            // mid-exit reverses seamlessly from wherever the retreat got to
            // (fully closed already sits at 0, so a fresh open is unchanged).
            deformAnimation.restart()
        } else {
            // Exit shares the submenu retract's parameters: slow(240ms) on
            // the inOut spline — a visible start, accelerating away under
            // the bar's occlusion — instead of the longer settings slide.
            deformAnimation.duration = MotionTokens.reducedMotion ? 0 : MotionTokens.slow
            deformAnimation.easing.type = Easing.BezierSpline
            deformAnimation.easing.bezierCurve = MotionTokens.inOut
            deformAnimation.to = 0
            deformAnimation.restart()
            Services.BarPopupService.pointerInPopup = false
        }
    }

    // Single deform progress drives scale and slide; there is no opacity
    // animation -- occlusion by the bar window does the hiding.
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
            // Same ordering law: anchor first, then swap content.
            root.frameAnchorX = Services.BarPopupService.anchorX
            root.shownKind = Services.BarPopupService.kind
            root.shownPayload = Services.BarPopupService.payload
        }
        // Same-kind payload swaps (tray icon A -> B) never flip `kind`, so
        // the surface must hear about the new payload directly. During a
        // fresh open the service commits payload before `kind`, so this
        // guard correctly skips that pre-visible assignment.
        function onPayloadChanged() {
            if (!Services.BarPopupService.visible)
                return
            root.shownPayload = Services.BarPopupService.payload
        }
        // Re-anchoring stays live only while the popup is open, so a close
        // can never drag the fading frame toward the reset-to-zero anchor.
        function onAnchorXChanged() {
            if (Services.BarPopupService.visible)
                root.frameAnchorX = Services.BarPopupService.anchorX
        }
    }

    NumberAnimation {
        id: deformAnimation

        target: root
        property: "deformProgress"
    }

    // Ends the placement phase when the fresh instance's frame actually
    // carries geometry: the loader activates after the open tick, so no
    // fixed delay is correct. The zero-born 0 -> dock transition thus
    // snaps while still hidden behind the bar; every later change glides.
    readonly property bool frameLive: surfaceLoader.width > 1 && surfaceLoader.height > 1
    onFrameLiveChanged: {
        if (frameLive)
            // Clear only after the whole creation binding pass has landed
            // (next event-loop turn), so x/y never get caught mid-pass.
            placementDone.start()
    }
    onDeformProgressChanged: {
        if (surfaceLoader.item && surfaceLoader.item.revealProgress !== undefined)
            surfaceLoader.item.revealProgress = deformProgress
    }

    // Safety valve: never let the guard stick if a surface stays empty.
    Timer {
        id: placementSettle

        interval: 250
        onTriggered: root.placingSurface = false
    }

    Timer {
        id: placementDone

        interval: 0
        onTriggered: root.placingSurface = false
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

        active: root.deformProgress > 0
        // Frame geometry is fully declarative: its left edge starts at the
        // trigger's left edge, then clamps against the screen's safe bounds.
        // This joins the panel to its bar component instead of floating it
        // around the trigger center.
        // Targets are computed from unanimated values so paired x/width
        // (and y/height) Behaviors glide in lockstep instead of chasing.
        readonly property real frameWidth: item ? item.implicitWidth : 0
        readonly property real frameHeight: item ? item.implicitHeight : 0
        readonly property real frameX: {
            if (!item)
                return 0
            var anchorScreenX = root.frameAnchorX + root.floatingMargin
            return Math.max(8, Math.min(anchorScreenX,
                                        root.width - frameWidth - 8))
        }
        readonly property real frameY: root.barTopAnchored
           ? 0
           : root.height - frameHeight
        width: frameWidth
        height: frameHeight
        x: frameX
        y: frameY
        // Retargets while fully open glide to their new frame instead of
        // teleporting; entrance/exit geometry stays unanimated so the
        // occlusion slide owns those phases.
        // Morph behaviors run for the whole open lifetime except the single
        // placement tick of a freshly created loader (zero-born geometry
        // must dock instantly, hidden behind the bar). Retargets on a live
        // instance always glide.
        readonly property bool morphReady: root.popupVisible && !root.placingSurface
        // slow(240) keeps the inter-widget glide readable; fast(100) read
        // as a flick. OutQuint matches every other popup transition.
        Behavior on x {
            enabled: surfaceLoader.morphReady
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: surfaceLoader.morphReady
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
        Behavior on width {
            enabled: surfaceLoader.morphReady
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
        Behavior on height {
            enabled: surfaceLoader.morphReady
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
        sourceComponent: {
            switch (root.shownKind) {
            case "tray": return trayMenuComponent
            case "barmenu": return barContextMenuComponent
            case "volume": return volumePopupComponent
            case "brightness": return brightnessPopupComponent
            case "clock": return calendarPopupComponent
            case "media": return mediaPopupComponent
            case "notifications": return notificationsPopupComponent
            default: return null
            }
        }

        onItemChanged: {
            if (item && item.revealProgress !== undefined)
                item.revealProgress = root.deformProgress
        }

        Component {
            id: trayMenuComponent

            BarTrayMenu { payload: root.shownPayload }
        }

        Component {
            id: barContextMenuComponent

            BarContextMenu {
                availHeight: root.height
                onOpenSettingsRequested: {
                    Services.BarPopupService.close()
                    SettingsOverlayBridge.openRequested()
                }
                onLayoutModeToggled: {
                    Services.BarPopupService.close()
                    Services.BarLayoutService.toggleSettingsMode()
                }
            }
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

    // The surface is already docked to the bar. Keep the host transform
    // translation-only; per-layer stagger belongs to BarPopupFrame.
    readonly property real enterTravel: surfaceLoader.height
    transform: Translate {
        y: MotionTokens.reducedMotion ? 0
           : (root.barTopAnchored ? -1 : 1) * root.enterTravel * (1 - root.deformProgress)
    }
}
