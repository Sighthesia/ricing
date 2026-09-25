pragma ComponentBehavior: Bound

import QtQuick
import "../lazerbar" as Lazer

// Edge-trailing reveal: the pink bands sweep the screenshot, and the pinned
// wallpaper is unveiled right at the band tail by a mask running the same
// geometry with a short delay. Three zones stay visible mid-sweep —
// screenshot ahead, pink bands, wallpaper behind — so the wave reads as
// unveiling the wallpaper instead of washing then covering.
Item {
    id: root
    property url snapshotSource: ""
    property url wallpaperSource: ""
    property real progress: 0
    // Mask delay in progress units: wide enough for a full pink zone, short
    // enough that the wallpaper arrives while the bands still sweep.
    readonly property real maskDelay: 0.3
    readonly property real maskProgress: Math.max(0, Math.min(1, (root.progress - root.maskDelay) / (1 - root.maskDelay)))
    readonly property bool snapshotReady: screenshot.status === Image.Ready
    readonly property bool imagesReady: snapshotReady && wallpaperBody.status === Image.Ready

    Rectangle {
        id: baseRect
        anchors.fill: parent
        // Follow the scheme so light mode never sits on a near-black floor
        // while images load or where the wallpaper stays dark.
        color: Lazer.LazerTheme.lightScheme
            ? "#EEEAF1" : Lazer.LazerTheme.bgDark
        Behavior on color { ColorAnimation { duration: Lazer.MotionTokens.fast } }
    }

    Image {
        id: screenshot
        anchors.fill: parent
        source: root.snapshotSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: status === Image.Ready
    }

    // Keep the four lock-surface wave layers static: WlSessionLockSurface does
    // not reliably render dynamically created visual delegates.
    Lazer.FullscreenWave {
        anchors.fill: parent
        progress: root.progress
        angle: 13
        colour: Lazer.LazerTheme.wavePalette.light4
        restOffset: -height * 0.72
    }
    Lazer.FullscreenWave {
        anchors.fill: parent
        progress: root.progress
        angle: -7
        colour: Lazer.LazerTheme.wavePalette.light3
        restOffset: -height * 0.5
    }
    Lazer.FullscreenWave {
        anchors.fill: parent
        progress: root.progress
        angle: 4
        colour: Lazer.LazerTheme.wavePalette.dark4
        restOffset: -height * 0.32
    }
    Lazer.FullscreenWave {
        anchors.fill: parent
        progress: root.progress
        angle: -2
        colour: Lazer.LazerTheme.wavePalette.dark3
        restOffset: -height * 0.16
    }

    // Reveal the pinned wallpaper with a bounded scene-graph clip. Keeping the
    // reveal rectangular avoids a live ShaderEffectSource/OpacityMask chain on
    // the compositor-owned session-lock surface.
    Item {
        id: wallpaperReveal
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.height * root.maskProgress
        clip: true
        visible: height > 0.5

        Image {
            id: wallpaperBody
            width: root.width
            height: root.height
            y: -(root.height - wallpaperReveal.height)
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
