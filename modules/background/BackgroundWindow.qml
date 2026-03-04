import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects
import qs.services

// Per-screen wallpaper window rendered at the background layer.
// One instance is created per monitor via Variants.
// Disc-reveal transition: new wallpaper expands from a random point as a growing circle.
Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot

        property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "dymicshell-background"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }

        color: "black"

        // ── Transition state ─────────────────────────────────────────
        // Normalized progress [0,1] — drives discMask size
        property real transitionProgress: 0.0

        // Disc center as fractions of screen size [0,1]
        property real discCenterX: 0.5
        property real discCenterY: 0.5

        // The diagonal of the screen — disc must be at least this large to cover everything
        readonly property real discMaxRadius: Math.hypot(bgRoot.width, bgRoot.height)

        // ── Current wallpaper (always visible) ───────────────────────
        Image {
            id: currentWallpaper
            anchors.fill: parent
            source: SettingsService.data.appearance.wallpaperPath !== ""
                    ? ("file://" + SettingsService.data.appearance.wallpaperPath)
                    : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false   // must be ready before transition starts
            cache: false
        }

        // ── Next wallpaper texture (invisible — used only by OpacityMask) ──
        Image {
            id: nextWallpaper
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            visible: false    // never painted directly; OpacityMask reads its texture
        }

        // ── Disc mask shape ──────────────────────────────────────────
        // White circle centered at (discCenterX, discCenterY) * screen size.
        // Growing radius reveals the new wallpaper beneath.
        Rectangle {
            id: discMask
            visible: false   // OpacityMask uses it as a texture only

            // Diameter grows from 0 to 2 * discMaxRadius driven by transitionProgress
            width:  bgRoot.transitionProgress * bgRoot.discMaxRadius * 2
            height: width
            radius: width / 2

            // Center on the chosen origin point
            x: bgRoot.discCenterX * bgRoot.width  - width / 2
            y: bgRoot.discCenterY * bgRoot.height - height / 2

            color: "white"
        }

        // ── Masked new-wallpaper layer ────────────────────────────────
        // Renders nextWallpaper clipped to discMask's circular shape,
        // floating above currentWallpaper.
        OpacityMask {
            anchors.fill: parent
            source:     nextWallpaper
            maskSource: discMask
        }

        // ── Animation ────────────────────────────────────────────────
        NumberAnimation {
            id: transitionAnim
            target:   bgRoot
            property: "transitionProgress"
            from:  0.0
            to:    1.0
            duration: 900
            easing.type: Easing.OutCubic

            onFinished: _swapAndReset()
        }

        // ── Swap helper: promote next→current, reset disc ────────────
        function _swapAndReset() {
            currentWallpaper.source   = nextWallpaper.source
            nextWallpaper.source      = ""
            transitionProgress        = 0.0
        }

        // ── Public API: start a transition to a new wallpaper ─────────
        // Called by the WallpaperChanged connection below.
        function startTransition(path) {
            // If an animation is already running, jump to end first
            if (transitionAnim.running) {
                transitionAnim.stop()
                _swapAndReset()
            }
            nextWallpaper.source  = "file://" + path
            discCenterX = Math.random()
            discCenterY = Math.random()
            transitionAnim.restart()
        }

        // ── React to wallpaper changes ────────────────────────────────
        Connections {
            target: WallpaperService
            function onWallpaperChanged(path) {
                bgRoot.startTransition(path)
            }
        }

        // ── Startup transition (disc from center after 150ms) ─────────
        Timer {
            id: startupTimer
            interval: 150
            repeat: false
            onTriggered: {
                if (SettingsService.data.appearance.wallpaperPath !== "") {
                    bgRoot.discCenterX = 0.5
                    bgRoot.discCenterY = 0.5
                    nextWallpaper.source = currentWallpaper.source
                    currentWallpaper.source = ""
                    bgRoot.transitionProgress = 0.0
                    transitionAnim.restart()
                }
            }
        }

        Component.onCompleted: startupTimer.start()
    }
}
