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

    // The launcher wave panel's pink bands, sweeping ahead of the wallpaper
    // mask below so the lock reveal carries the same decoration. The bands
    // share the mask's progress (like the launcher waves tracking the body)
    // with only a small geometric lead: two edge systems running at
    // different speeds read as flicker, while a steady sliver reads as one
    // curtain. The catching-up wallpaper covers the bands by the settled
    // frame, which is unchanged.
    Lazer.WaveRevealLayers {
        id: waveDecoration
        anchors.fill: parent
        progress: root.progress
        palette: Lazer.LazerTheme.wavePalette
        leadOffset: -height * 0.10
        reverseOrder: true
    }

    Item {
        id: maskItem
        objectName: "lockMask"
        anchors.fill: parent

        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
            angle: WaveLogic.waveAngle(0)
            restOffset: -height * 0.72
            colour: "white"
            opacity: 1
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
            angle: WaveLogic.waveAngle(1)
            restOffset: -height * 0.5
            colour: "white"
            opacity: 1
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
            angle: WaveLogic.waveAngle(2)
            restOffset: -height * 0.32
            colour: "white"
            opacity: 1
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
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
