pragma ComponentBehavior: Bound

import QtQuick
import "../lazerbar" as Lazer

// Three layers mirroring the launcher wave panel: a static background, the
// pink bands as the sweeping foreground, and the wallpaper as the body that
// slides up over the bands and covers them at rest.
Item {
    id: root
    property url snapshotSource: ""
    property url wallpaperSource: ""
    property real bandsProgress: 0
    property real bodyProgress: 0
    readonly property bool snapshotReady: screenshot.status === Image.Ready
    readonly property bool imagesReady: snapshotReady && wallpaperBody.status === Image.Ready

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
    // palette, geometry, stacking, and opacity ramp. They sweep the static
    // screenshot exactly like the launcher sweep over the desktop.
    Lazer.WaveRevealLayers {
        id: waveDecoration
        anchors.fill: parent
        progress: root.bandsProgress
        palette: Lazer.LazerTheme.wavePalette
    }

    // Wallpaper body: slides up and fades exactly like the launcher body,
    // covering the bands at rest. No mask chain — direct scene drawing, so
    // the bands keep full ownership of the sweep.
    Image {
        id: wallpaperBody
        width: parent.width
        height: parent.height
        x: 0
        y: parent.height * (1 - root.bodyProgress)
        opacity: root.bodyProgress
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
