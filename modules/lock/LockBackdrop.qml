pragma ComponentBehavior: Bound

import QtQuick
import "../lazerbar" as Lazer
import "../lazerbar/WallpaperSlotLogic.js" as SlotLogic

// Edge-trailing reveal: the pink bands sweep the themed lock surface, and the
// pinned wallpaper is unveiled right at the band tail by a mask running the
// same geometry with a short delay. Three zones stay visible mid-sweep —
// themed surface ahead, pink bands, wallpaper behind — so the wave reads as
// unveiling the wallpaper instead of washing then covering.
Item {
    id: root
    property url snapshotSource: ""
    property url wallpaperSource: ""
    // Whether this request expects a capture at all. The session-start lock
    // deliberately has none: there is no settled desktop to photograph, so it
    // unveils the wallpaper over the opaque floor. Waiting on that empty slot as
    // if it were a pending image would burn the whole bounded grace window before
    // the lock screen ever appeared. A capture that *was* expected and failed
    // still gets the same bounded wait.
    property bool captureExpected: true
    property real progress: 0
    // Device pixel ratio the wallpaper layer decodes for. Supplied by the lock
    // owner; one is the safe floor.
    property real decodeRatio: 1
    property bool lightScheme: Lazer.LazerTheme.lightScheme
    property color surfaceColorOverride: "transparent"
    // Mask delay in progress units: wide enough for a full pink zone, short
    // enough that the wallpaper arrives while the bands still sweep.
    readonly property real maskDelay: 0.3
    readonly property real maskProgress: Math.max(0, Math.min(1, (root.progress - root.maskDelay) / (1 - root.maskDelay)))
    readonly property bool snapshotReady: !root.captureExpected
            || screenshot.status === Image.Ready
    // Decode budget for the wallpaper layer, shared with the wallpaper window's
    // slots so both hold the same pixels. `decodeRatio` comes from the lock owner
    // (the highest ratio among the session's screens): decoding short of a
    // panel's ratio buys blur instead of memory, so an over-estimate is the safe
    // direction when one lock surface serves every screen.
    readonly property size wallpaperDecodeSize: {
        var decode = SlotLogic.sourceSize(root.width, root.height,
                                         root.decodeRatio,
                                         8 * 1024 * 1024)
        return Qt.size(decode.width, decode.height)
    }
    readonly property bool imagesReady: snapshotReady && wallpaperBody.status === Image.Ready
    readonly property bool revealContentInteractive: openedRegion.height > 0.5
    readonly property Item revealContentHost: foregroundBody
    readonly property color surfaceColor: root.surfaceColorOverride.a > 0.5
            ? root.surfaceColorOverride
            : (root.lightScheme ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.bgDark)
    default property alias content: foregroundBody.data

    // The wallpaper, full screen and *not* clipped.
    //
    // It used to live inside the opening region's clip, which is where it broke:
    // every value the wave reads was correct — decoded, sized to the surface,
    // mask fully open — and the screen stayed on the flat plate anyway, because a
    // WlSessionLockSurface will not render an Image inside a clipped subtree. The
    // same image renders perfectly off the lock surface, and the sibling
    // `screenshot` (also a plain full-screen Image, also unclipped) has always
    // painted there, so the clip is what moved the failure, not the decode.
    //
    // So the clip moved to the layers above it instead: the wallpaper is the
    // bottom of the stack, and the opaque plate is what the wave cuts away. Same
    // three zones in the same order, and no clipped image anywhere.
    Image {
        id: wallpaperBody
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        visible: String(root.wallpaperSource).length > 0
        // Decoded off the GUI path: the plate still covers this layer until the
        // mask opens, so a late decode is never seen. `imagesReady` gates the
        // wave on it.
        asynchronous: true
        // Same decode budget as the wallpaper window's slots. This is a second
        // full-screen decode of a file that is already resident behind the lock,
        // so it is capped the same way rather than at the file's own resolution.
        sourceSize: root.wallpaperDecodeSize
    }

    // Everything the wave has not opened yet: the themed plate, the pre-lock
    // capture, and the four bands sweeping across them. Clipped to the region
    // above the mask, so it is cut away from the bottom as the wave passes and
    // the wallpaper underneath takes over. Clipping an opaque rectangle is safe
    // on this surface; clipping the image was not.
    //
    // The bands live in here too, and that is not a convenience: they used to be
    // painted *under* the revealed wallpaper and read as trailing behind its edge.
    // Confining them to the un-opened side reproduces those exact pixels without
    // putting the wallpaper back under a clip — they sweep down and leave the
    // screen anyway, so nothing is lost by cutting them at the mask line.
    Item {
        id: coveredBase
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.height * (1 - root.maskProgress)
        clip: true
        visible: height > 0.5

        Rectangle {
            id: baseRect
            anchors.fill: parent
            // Paint a deterministic theme surface until the wallpaper is revealed.
            color: root.surfaceColor
            Behavior on color { ColorAnimation { duration: Lazer.MotionTokens.fast } }
        }

        // The pre-lock screenshot is the base the wave sweeps across; the themed
        // floor only shows through when a screen produced no capture.
        Image {
            id: screenshot
            anchors.fill: parent
            source: root.snapshotSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            visible: String(root.snapshotSource).length > 0
        }

        // Keep the four lock-surface wave layers static: WlSessionLockSurface does
        // not reliably render dynamically created visual delegates. They also sit
        // above the plate, which a full-width opaque body would otherwise hide for
        // the life of the surface.
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
    }

    // The opened region: the same geometry the wallpaper reveal always had,
    // because it is the same reveal. It carries the lock controls so they arrive
    // with the wallpaper rather than sitting over the plate. It holds no image —
    // the wallpaper is the full-screen layer underneath `coveredBase`.
    Item {
        id: openedRegion
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.height * root.maskProgress
        clip: true
        visible: height > 0.5

        // Keep lock controls in the same layer as the wallpaper they sit on.
        Item {
            id: foregroundBody
            width: root.width
            height: root.height
            // Align the full-surface content with the clipped region.
            y: -(root.height - openedRegion.height)
        }
    }
}
