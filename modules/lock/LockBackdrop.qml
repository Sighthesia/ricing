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
    // Whether the unlock choreography is under way. It closes the entry-time
    // opened region, hides the covered base, and brings the free-sweep exit
    // bands up: the closing wave travels top-down and every region it passes
    // shows the live desktop beneath the transparent lock surface.
    property bool exiting: false
    property bool exitWaveActive: false
    property real entryBodyProgress: 0
    property real exitBodyProgress: 1
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
    // The exit handoff is not allowed to begin while its replacement desktop
    // image is still decoding. Keeping this true until Image.Ready preserves
    // the complete lock surface instead of exposing the compositor clear color.
    readonly property bool exitDesktopReady: !root.exiting
            || exitDesktop.status === Image.Ready
    readonly property bool revealContentInteractive: openedRegion.height > 0.5
    readonly property Item revealContentHost: foregroundBody
    readonly property color surfaceColor: root.surfaceColorOverride.a > 0.5
            ? root.surfaceColorOverride
            : (root.lightScheme ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.bgDark)
    default property alias content: foregroundBody.data

    // The guaranteed-opaque floor, painted under everything. A session-lock
    // surface may not show the desktop before it has committed a frame, so the
    // floor is unconditional and full-screen while the lock is in place. It
    // stands down only once the exit wave actually moves (progress < 1): the
    // exit bands at rest cover the full screen from the first sweep frame, so
    // the floor hands over to them seamlessly — while the content fall that
    // precedes the wave still plays over the opaque floor instead of a
    // desktop that pops in before the wave passes.
    Rectangle {
        id: baseRect
        anchors.fill: parent
        // Keep the lock floor until the exit image has decoded. The exit
        // surface is enabled before its Image necessarily has pixels; dropping
        // the floor on progress alone exposed the compositor's dark clear color
        // for the first frames of unlock.
        // Keep the floor during the content-fall phase, but hand it off as
        // soon as the closing wave is actually active. At that first exit
        // frame progress is still 1; using progress as the visibility gate
        // left this full-screen dark floor above the wave for a visible beat.
        visible: !root.exiting || !root.exitWaveActive || !root.exitDesktopReady
        // The theme surface, as the floor has always been.
        color: root.surfaceColor
        Behavior on color { ColorAnimation { duration: Lazer.MotionTokens.fast } }
    }

    // Everything the wave has not opened yet: the pre-lock capture, and the
    // themed floor behind it. On entry this is the region above the trailing
    // mask. On exit it stays closed — the exit sweep carries the bands on its
    // own free layer below, and what the wave has passed must show the live
    // desktop through the transparent surface, not a screenshot or a floor.
    Item {
        id: coveredBase
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.height * (1 - root.maskProgress)
        clip: true
        z: 1
        visible: !root.exiting && height > 0.5

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

    }

    // Entry wave viewport: fixed to the full lock surface like the launcher
    // host. The opened region below is painted above it, so the oversized wave
    // rectangles are naturally swallowed by the arriving wallpaper instead of
    // being clipped to the shrinking covered region.
    Item {
        id: entryBands
        anchors.fill: parent
        z: 2
        visible: !root.exiting

        // Keep the launcher geometry, but declare the layers statically:
        // WlSessionLockSurface does not reliably render Repeater delegates.
        // These values mirror WaveSurfaceLogic/WaveRevealLayers exactly.
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

    // The exit sweep's own bands: the same four layers, full-screen and
    // unclipped, travelling DOWN with the closing progress (rest -> hidden).
    // Above (behind) each band's head the live desktop shows through the
    // transparent lock surface; below (ahead) the band still covers. They
    // live outside coveredBase because that clip would hide them: at exit
    // start they sit above the viewport top while the covered region is
    // zero-height, so nothing would ever be painted. On entry they stay
    // invisible — coveredBase owns the entry sweep — and the exit keeps them
    // opaque until the sweep lands. Reduced motion jumps progress to 0, the
    // bands land on their hidden offsets and vanish with no flash.
    Item {
        id: exitBands
        anchors.fill: parent
        z: 2
        opacity: root.exiting ? 1 : 0
        visible: root.exiting || opacity > 0

        // Same launcher geometry, statically declared for the session-lock
        // renderer. The wallpaper body stays above these layers and the desktop
        // image stays below them, matching the launcher's moving body contract.
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

    // Desktop image carried by the exit sweep. A transparent session-lock
    // region is not guaranteed to composite the live desktop underneath it;
    // on niri that path can expose the compositor's solid floor instead. The
    // manual-lock snapshot is the exact desktop from before the lock, so use
    // it as the transition surface. Startup locks intentionally have no
    // snapshot and fall back to the configured wallpaper, which is the only
    // desktop content that exists before the session is assembled.
    Item {
        id: exitDesktopRegion
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // The desktop belongs only to the part already passed by the closing
        // wave. Keeping the image full-screen here made it paint over the
        // entire lock surface as soon as exitStarted flipped, so the screen
        // changed to the dark desktop/theme image before the bands moved.
        height: root.height
        z: 1
        visible: root.exiting && exitDesktop.status === Image.Ready

        Image {
            id: exitDesktop
            width: root.width
            height: root.height
            anchors.top: parent.top
            source: String(root.snapshotSource).length > 0
                    ? root.snapshotSource : root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            sourceSize: root.wallpaperDecodeSize
        }
    }

    // The opened region: the entry-time trailing mask, plus the exit plate.
    // On entry it grows with the sweep and carries the wallpaper plus the
    // lock controls. On exit it closes with raw `progress` — NOT this
    // maskProgress, whose delay lead would swallow the plate at progress 0.3
    // (70% through the animation) while the bands are still mid-screen. The
    // raw progress matches the bands' own travel, so the wallpaper plate
    // slides down under the wave column and only vanishes as the last band
    // lands off the bottom edge.
    Item {
        id: openedRegion
        z: 3
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.height
        clip: true
        visible: height > 0.5

        // Move one full-height lock body through the viewport on exit, matching
        // the launcher's two-viewport body travel so the oversized wave can
        // fully unfold instead of being trapped between two one-height regions.
        Item {
            id: openedContent
            width: root.width
            height: root.height
            // Both directions use the launcher's two-viewport body travel. On
            // entry this keeps the opaque lock body below the wave until the
            // stretched bands have established themselves; on exit it leaves
            // the pinned wallpaper behind the falling wave.
            clip: true
            y: root.height * 2 * (1 - (root.exiting
                    ? root.exitBodyProgress : root.entryBodyProgress))

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
            // The lock controls travel with the launcher-style body on exit,
            // but the wallpaper must stay pinned to the lock surface. Cancel
            // the body's translation here so the closing wave moves across a
            // stationary wallpaper instead of dragging the image downward.
            x: 0
            y: root.exiting ? -openedContent.y : 0

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
            anchors.fill: parent
        }
        }
    }
}
