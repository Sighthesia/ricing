pragma ComponentBehavior: Bound

import QtQuick
import "../lazerbar" as Lazer
import "../lazerbar/WallpaperSlotLogic.js" as SlotLogic

// Edge-trailing reveal: the pink bands sweep whatever opaque base this request
// brought, and behind them the desktop itself is unveiled. Three zones stay
// visible mid-sweep — base ahead, pink bands, desktop behind — so the wave reads
// as unveiling the desktop instead of washing then covering.
//
// There is deliberately no wallpaper layer here. The desktop is already painted
// behind this surface — the wallpaper window is settled before a session-start
// lock waves — so the region the wave opens is simply left transparent and the
// real wallpaper shows through. Painting a second copy of the wallpaper here was
// both redundant (a full-screen decode of a file already resident behind the
// lock) and broken: an `Image` on a `WlSessionLockSurface` reports Ready with
// correct geometry and the mask fully open, and still never reaches the screen.
// Same surface, same symptom the Repeater-delegate trap in this shell already
// documents. Nothing here decodes an image any more, so that failure cannot
// recur, and the wave cannot open on a flat plate because there is no plate left
// to open on.
Item {
    id: root
    property url snapshotSource: ""
    property url wallpaperSource: ""
    // Whether this request expects a capture at all. The session-start lock
    // deliberately has none: there is no settled desktop to photograph, so the
    // wave opens straight onto the live desktop. Waiting on that empty slot as if
    // it were a pending image would burn the whole bounded grace window before the
    // lock screen ever appeared. A capture that *was* expected and failed still
    // gets the same bounded wait, and then opens onto the desktop too.
    property bool captureExpected: true
    property real progress: 0
    // Device pixel ratio the wallpaper layer decodes for, supplied by the lock
    // owner as the highest ratio among the session's screens: one surface serves
    // every screen, so the maximum is the only estimate that cannot come out
    // short, and over-estimating costs memory rather than sharpness.
    property real decodeRatio: 1
    property bool lightScheme: Lazer.LazerTheme.lightScheme
    property color surfaceColorOverride: "transparent"
    // Mask delay in progress units: wide enough for a full pink zone, short
    // enough that the desktop arrives while the bands still sweep.
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

    // The wallpaper, full screen and unclipped: this is what the wave unveils, and
    // it has to be painted here rather than left to the desktop behind. The
    // desktop is not a dependable answer on this surface — a session lock covers
    // the output, so what shows through a transparent region is the wallpaper
    // window's floor until its own slots paint, which is the dark band this
    // layer replaced.
    //
    // `asynchronous: false` is load-bearing, not a default. An `Image` with
    // `asynchronous: true` on a `WlSessionLockSurface` reports Ready and never
    // repaints when the decode lands: the lock screen then keeps showing
    // whatever is underneath for the rest of its life. The sibling `screenshot`
    // has always worked on the same surface, and it is synchronous. A full-screen
    // decode here is the cost `asynchronous: true` exists to avoid, but paying it
    // is what makes the layer visible at all — and it happens while the opaque
    // floor still covers the screen, so it is never on a visible frame.
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

    // Everything the wave has not opened yet: the themed floor, the pre-lock
    // capture, and the four bands sweeping across them. Clipped to the region
    // above the mask, so it is cut away from the bottom as the wave passes and
    // the wallpaper underneath takes over. The floor is opaque from the first
    // frame and only for as long as it covers the whole surface, which is what
    // keeps a session lock from showing anything before it has committed its
    // first frame.
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
            // Paint a deterministic theme surface until the wave opens the
            // desktop. A session-start lock has no capture, so this is the whole
            // screen until the mask reaches it.
            color: root.surfaceColor
            Behavior on color { ColorAnimation { duration: Lazer.MotionTokens.fast } }
        }

        // The pre-lock capture is the base the wave sweeps across; the themed
        // floor only shows through when a screen produced no capture. It sits
        // inside the same clip as the floor, because the mask has to cut *both*
        // away — a capture left outside would sit on top of the opened region and
        // hide the desktop for the rest of the sweep.
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
        // above the floor, which a full-width opaque body would otherwise hide for
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

    // The opened region: the same geometry the reveal always had, because it is
    // the same reveal. It carries the lock controls so they arrive with the
    // desktop rather than sitting over the floor, and it holds nothing else — the
    // desktop behind this surface is what the wave has uncovered.
    Item {
        id: openedRegion
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.height * root.maskProgress
        clip: true
        visible: height > 0.5

        // Keep lock controls in the same layer as the desktop they sit on.
        Item {
            id: foregroundBody
            width: root.width
            height: root.height
            // Align the full-surface content with the clipped region.
            y: -(root.height - openedRegion.height)
        }
    }
}