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
        // Ignore the bar's exclusive zone so the background covers the full screen.
        exclusionMode: ExclusionMode.Ignore

        color: "black"

        // ── Transition state ─────────────────────────────────────────
        property real transitionProgress: 0.0
        property real discCenterX: 0.5
        property real discCenterY: 0.5
        readonly property real discMaxRadius: Math.hypot(bgRoot.width, bgRoot.height)

        // ── Current wallpaper — source managed imperatively to avoid startup flash ──
        Image {
            id: currentWallpaper
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
        }

        // ── Next wallpaper texture (read by OpacityMask; never painted directly) ──
        Image {
            id: nextWallpaper
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            visible: false
        }

        // ── Disc mask container ───────────────────────────────────────
        // Must fill the entire screen with layer.enabled so OpacityMask
        // samples the mask at screen resolution — prevents the circle from
        // being stretched into an ellipse on non-square viewports.
        Item {
            id: discMaskContainer
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                width:  bgRoot.transitionProgress * bgRoot.discMaxRadius * 2
                height: width
                radius: width / 2
                x: bgRoot.discCenterX * bgRoot.width  - width / 2
                y: bgRoot.discCenterY * bgRoot.height - height / 2
                color: "white"
            }
        }

        // ── Masked new-wallpaper layer ────────────────────────────────
        OpacityMask {
            anchors.fill: parent
            source:     nextWallpaper
            maskSource: discMaskContainer
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

        function _swapAndReset() {
            currentWallpaper.source = nextWallpaper.source
            nextWallpaper.source    = ""
            transitionProgress      = 0.0
        }

        function startTransition(path) {
            if (transitionAnim.running) {
                transitionAnim.stop()
                _swapAndReset()
            }
            nextWallpaper.source = "file://" + path
            discCenterX = Math.random()
            discCenterY = Math.random()
            transitionAnim.restart()
        }

        Connections {
            target: WallpaperService
            function onWallpaperChanged(path) {
                bgRoot.startTransition(path)
            }
        }

        // ── Startup transition ────────────────────────────────────────
        // Screen starts black; after 150 ms the saved wallpaper disc-reveals
        // from the center. No initial source binding avoids the pre-animation flash.
        Timer {
            id: startupTimer
            interval: 150
            repeat: false
            onTriggered: {
                let path = SettingsService.data.appearance.wallpaperPath
                if (path !== "") {
                    bgRoot.discCenterX = 0.5
                    bgRoot.discCenterY = 0.5
                    nextWallpaper.source   = "file://" + path
                    bgRoot.transitionProgress = 0.0
                    transitionAnim.restart()
                }
            }
        }

        Component.onCompleted: startupTimer.start()
    }
}
