pragma ComponentBehavior: Bound

import QtQuick
import "../lazerbar" as Lazer
import "../lazerbar/WallpaperSlotLogic.js" as SlotLogic

// Edge-trailing reveal: the pink bands sweep whatever base this request brought,
// and behind them the wallpaper is unveiled. Mid-sweep three zones stay visible —
// base ahead, pink bands, wallpaper behind — so the wave reads as unveiling the
// wallpaper instead of washing then covering.
//
// Only two things are ever in front of the wallpaper, and neither of them is a
// flat plate: a pre-lock capture, which only a manual lock brings, and the four
// bands. The wallpaper itself lives inside the opened region, under the same
// trailing mask that carries the lock controls — so a session-start lock reads
// as floor, then bands sweeping, then wallpaper and controls arriving together.
// Nothing pops in ahead of the wave.
//
// The themed floor is painted from the first frame, underneath everything. A
// session-lock surface must commit an opaque first frame and cannot rely on the
// wallpaper's decode having landed by then, so the floor cannot be conditional —
// and it is still the base whenever there is no wallpaper to show or the
// wallpaper failed to decode.
Item {
    id: root
    property url snapshotSource: ""
    property url wallpaperSource: ""
    // Whether this request expects a capture at all. The session-start lock
    // deliberately has none: there is no settled desktop to photograph, so the
    // wave opens straight onto the wallpaper. Waiting on that empty slot as if
    // it were a pending image would burn the whole bounded grace window before the
    // lock screen ever appeared. A capture that *was* expected and failed still
    // gets the same bounded wait, and then opens onto the wallpaper too.
    property bool captureExpected: true
    property real progress: 0
    // Whether the unlock choreography is under way. It flips the backdrop's
    // geometry from "opened region at the bottom grows upward" to "covered
    // region at the top shrinks downward", so the downward exit sweep unveils
    // the live desktop beneath the lock surface instead of washing the
    // wallpaper into the solid floor before the pop of release.
    property bool exiting: false
    // Fraction of the screen the exit sweep has already unveiled. The wave
    // head travels top-down with `progress` falling 1 -> 0; the desktop shows
    // through everywhere the head has passed. The maskDelay lead keeps the
    // same head/tail relationship the entry has (bands sweep ahead of the
    // desktop edge) but read from the closing side.
    readonly property real exitCoverProgress: Math.max(0, Math.min(1, 1 - root.progress))
    // Device pixel ratio the wallpaper layer decodes for, supplied by the lock
    // owner as the highest ratio among the session's screens: one surface serves
    // every screen, so the maximum is the only estimate that cannot come out
    // short, and over-estimating costs memory rather than sharpness.
    property real decodeRatio: 1
    property bool lightScheme: Lazer.LazerTheme.lightScheme
    property color surfaceColorOverride: "transparent"
    // Mask delay in progress units: wide enough for a full pink zone to establish
    // itself as a travelling wave, short enough that the wallpaper and the lock
    // controls arrive while the bands still sweep. It no longer serves to hold a
    // flat plate on screen — nothing opaque sits in front of the wallpaper any
    // more — so all it decides now is how much of the sweep the bands own before
    // the trailing mask starts eating them from below.
    readonly property real maskDelay: 0.3
    readonly property real maskProgress: Math.max(0, Math.min(1, (root.progress - root.maskDelay) / (1 - root.maskDelay)))
    readonly property bool snapshotReady: !root.captureExpected
            || screenshot.status === Image.Ready
    // Decode budget for the wallpaper layer, shared with the wallpaper window's
    // slots so both hold comparable pixels.
    readonly property size wallpaperDecodeSize: {
        var decode = SlotLogic.sourceSize(root.width, root.height,
                                         root.decodeRatio,
                                         8 * 1024 * 1024)
        return Qt.size(decode.width, decode.height)
    }
    readonly property bool imagesReady: snapshotReady
            && wallpaperBody.status === Image.Ready
    readonly property bool revealContentInteractive: openedRegion.height > 0.5
    readonly property Item revealContentHost: foregroundBody
    readonly property color surfaceColor: root.surfaceColorOverride.a > 0.5
            ? root.surfaceColorOverride
            : (root.lightScheme ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.bgDark)
    default property alias content: foregroundBody.data

    // The guaranteed-opaque floor, painted under everything. A session-lock
    // surface may not show the desktop before it has committed a frame, so the
    // floor is unconditional and full-screen while the lock is in place — but
    // it yields during the exit sweep, where the region below the wave head is
    // the desktop the wave is unveiling and must not stay floored. Without
    // this the exit reads as the wallpaper dissolving into a flat plate.
    visible: !root.exiting
    Rectangle {
        id: baseRect
        anchors.fill: parent
        // The theme surface, as the floor has always been.
        color: root.surfaceColor
        Behavior on color { ColorAnimation { duration: Lazer.MotionTokens.fast } }
    }

    // Everything the wave has not opened yet: the pre-lock capture, and the four
    // bands sweeping across it. On entry this covers everything above the
    // trailing mask; on exit the wave closes top-down and the region it has
    // swept must show the desktop beneath the lock surface, so this whole
    // item shrinks to the region above the wave *head* (below it the desktop
    // shows through the transparent surface). Clipped to that region, so it is
    // cut away from the bottom as the wave passes.
    Item {
        id: coveredBase
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.exiting
                ? root.height * root.exitCoverProgress
                : root.height * (1 - root.maskProgress)
        clip: true
        visible: height > 0.5

        // The pre-lock capture is the base the wave sweeps across. It sits inside
        // this clip because the mask has to cut it away — a capture left outside
        // would sit on top of the opened region and hide the wallpaper for the
        // rest of the sweep.
        Image {
            id: screenshot
            anchors.fill: parent
            source: root.snapshotSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            visible: String(root.snapshotSource).length > 0
        }

        // Keep the four lock-surface wave layers static: WlSessionLockSurface does
        // not reliably render dynamically created visual delegates. They sit above
        // the capture, which is what lets them read as a wave sweeping *something*
        // — the capture for a manual lock, the themed floor for a session-start
        // lock. The wallpaper they unveil lives in the opened region below.
        // Rest offsets are osu WaveContainer.FinalPosition absolutes; odd layers
        // anchor right like osu's TopRight second/fourth waves.
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
            angle: 13
            colour: Lazer.LazerTheme.wavePalette.light4
            restOffset: -930
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
            angle: -7
            anchorRight: true
            colour: Lazer.LazerTheme.wavePalette.light3
            restOffset: -560
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
            angle: 4
            colour: Lazer.LazerTheme.wavePalette.dark4
            restOffset: -390
        }
        Lazer.FullscreenWave {
            anchors.fill: parent
            progress: root.progress
            angle: -2
            anchorRight: true
            colour: Lazer.LazerTheme.wavePalette.dark3
            restOffset: -220
        }
    }

    // The opened region: the same geometry the reveal always had, because it is
    // the same reveal. It carries the lock controls so they arrive with the
    // wallpaper rather than sitting over the floor, and it holds nothing else —
    // the wallpaper underneath is what the wave has uncovered. Gone during the
    // exit: the downward sweep unveils the live desktop, not this entry-time
    // wallpaper plate (whose controls have already fallen away).
    Item {
        id: openedRegion
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.exiting ? 0 : root.height * root.maskProgress
        clip: true
        visible: height > 0.5

        // The wallpaper the wave unveils, sitting under the lock controls so
        // both arrive with the same trailing edge. It is hosted in a full-height
        // inner item rather than filling the clipped region directly: the region
        // grows every frame, and an image anchored to it would re-crop and read
        // as the wallpaper zooming with the wave. Filling a constant-size item
        // keeps the crop fixed; only the clip moves.
        //
        // `asynchronous: false` is
        // load-bearing, not a default: an `Image` with `asynchronous: true` on a
        // `WlSessionLockSurface` reports Ready and never repaints when the decode
        // lands, so the lock screen would keep showing whatever is underneath for
        // the rest of its life. The sibling `screenshot` has always worked on the
        // same surface, and it is synchronous. A full-screen decode is the cost
        // `asynchronous: true` exists to avoid, but paying it is what makes the
        // layer visible at all — and it is paid while the opaque floor still backs
        // this surface, so it is never the only thing standing between the lock
        // and the desktop.
        Item {
            id: wallpaperHost
            width: root.width
            height: root.height
            // Align with the full surface, like foregroundBody below.
            y: -(root.height - openedRegion.height)

            Image {
                id: wallpaperBody
                anchors.fill: parent
                source: root.wallpaperSource
                fillMode: Image.PreserveAspectCrop
                visible: String(root.wallpaperSource).length > 0
                asynchronous: false
                // Same budget as the wallpaper window's slots, so the lock does not decode
                // a 4K file at full size to fill a screen it already has a capped decode of.
                sourceSize: root.wallpaperDecodeSize
            }
        }

        // Keep lock controls in the same layer as the wallpaper they sit on.
        // The wallpaper fills a full-height inner item so the crop never
        // re-scales with the growing clip (see wallpaperHost above).
        Item {
            id: foregroundBody
            width: root.width
            height: root.height
            // Align the full-surface content with the clipped region.
            y: -(root.height - openedRegion.height)
        }
    }
}