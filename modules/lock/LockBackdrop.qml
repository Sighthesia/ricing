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
    // mask below so the lock reveal carries the same decoration. At rest the
    // fully revealed wallpaper covers them, so the settled frame is unchanged.
    Lazer.WaveRevealLayers {
        id: waveDecoration
        anchors.fill: parent
        progress: root.progress
        palette: Lazer.LazerTheme.wavePalette
        leadOffset: -height * 0.10
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
