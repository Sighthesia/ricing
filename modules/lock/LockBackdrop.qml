pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "../lazerbar" as Lazer
import "../lazerbar/WaveSurfaceLogic.js" as WaveLogic

Item {
    id: root
    property url snapshotSource: ""
    property url wallpaperSource: ""
    property real progress: 0
    // Two-phase reveal mirroring the launcher wave panel: the pink bands
    // sweep the screenshot alone first (like waves over the desktop), then
    // the wallpaper mask sweeps over the pink (like the body over waves).
    // One moving edge system at a time so the sweep never shimmers.
    readonly property real bandsProgress: Math.min(1, root.progress * 2)
    readonly property real maskProgress: Math.max(0, Math.min(1, (root.progress - 0.5) * 2))
    readonly property bool snapshotReady: screenshot.status === Image.Ready
    readonly property bool imagesReady: snapshotReady && wallpaper.status === Image.Ready

    Rectangle {
        id: baseRect
        anchors.fill: parent
        color: Lazer.LazerTheme.bgDark
    }

    Image {
        id: screenshot
        anchors.fill: parent
        source: root.snapshotSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: status === Image.Ready
    }

    // The launcher wave panel's bands with zero customization: same
    // palette, geometry, stacking, and opacity ramp. They run on the first
    // phase while the wallpaper mask waits, so the full bands read exactly
    // like the launcher sweep.
    Lazer.WaveRevealLayers {
        id: waveDecoration
        anchors.fill: parent
        progress: root.bandsProgress
        palette: Lazer.LazerTheme.wavePalette
    }

    Item {
        id: maskItem
        objectName: "lockMask"
        anchors.fill: parent

        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.maskProgress
            angle: WaveLogic.waveAngle(0)
            restOffset: -height * 0.72
            colour: "white"
            opacity: 1
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.maskProgress
            angle: WaveLogic.waveAngle(1)
            restOffset: -height * 0.5
            colour: "white"
            opacity: 1
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.maskProgress
            angle: WaveLogic.waveAngle(2)
            restOffset: -height * 0.32
            colour: "white"
            opacity: 1
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.maskProgress
            angle: WaveLogic.waveAngle(3)
            restOffset: -height * 0.16
            colour: "white"
            opacity: 1
        }
    }

    ShaderEffectSource {
        id: maskTexture
        anchors.fill: parent
        sourceItem: maskItem
        hideSource: true
        // Keep live: freezing on settled frames was tried and reverted —
        // the frozen texture is always one animation tick stale, leaving a
        // permanent pink sliver under the fully revealed wallpaper.
        live: true
        visible: false
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: maskTexture }
    }
}
