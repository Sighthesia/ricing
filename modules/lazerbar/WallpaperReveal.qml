pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "WallpaperReveal.js" as RevealLogic

// Reveal a wallpaper through a circle that grows from the point the user
// triggered the switch, so the new wallpaper appears to spread out of the click.
//
// Structure follows the DymicShell background window: the next wallpaper is a
// hidden image, a full-screen mask container holds the circle, and an
// OpacityMask item paints the result. Two details are load-bearing:
//   * `asynchronous: false` — the reveal must never start before the pixels
//     exist, and the settled layer must be able to take the same source in one
//     synchronous step. A full-screen wallpaper is far larger than QPixmapCache's
//     10 MB limit, so an async reload always re-decodes from disk and flashes.
//   * the mask container fills the surface with `layer.smooth`, so the mask is
//     sampled at screen resolution instead of being stretched into an ellipse.
//
// QtQuick.Shapes cannot be used for the circle (its antialiased edges pick up a
// 1px white ring), ShaderEffect cannot be used either (Qt 6.11 only accepts
// precompiled .qsb shaders), and MultiEffect's mask pass drops the source.
Item {
    id: root

    // Incoming wallpaper path. The host clears it once the reveal is handed over.
    property string source: ""
    // Boot can decode off the GUI path before the reveal starts; live swaps keep
    // this false so their synchronous handover contract remains unchanged.
    property bool asynchronous: false
    // Circle centre, in this item's coordinates.
    property point origin: Qt.point(0, 0)
    // Current circle radius in pixels; 0 means nothing is revealed.
    property real radius: 0
    // Radius that covers the whole surface from `origin`.
    readonly property real coverRadius: RevealLogic.coverRadius(root.origin.x, root.origin.y, root.width, root.height)
    // A decoded incoming wallpaper is what the host waits for before growing.
    readonly property bool imageReady: nextWallpaper.status === Image.Ready
    readonly property bool imageFailed: nextWallpaper.status === Image.Error

    // Incoming wallpaper, decoded offstage and never painted directly: the mask
    // samples it into a texture instead.
    Image {
        id: nextWallpaper
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: root.asynchronous
        cache: false
        visible: false
    }

    // Mask container: full-screen so the mask is sampled 1:1, with the circle
    // inside it. The circle is exactly covered by the opaque part of the mask
    // result below, so the white fill never shows.
    Item {
        id: discMask
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            width: Math.max(0, root.radius) * 2
            height: width
            radius: width / 2
            x: root.origin.x - width / 2
            y: root.origin.y - height / 2
            color: "white"
        }
    }

    // Masked incoming wallpaper, drawn above the settled layer.
    OpacityMask {
        anchors.fill: parent
        visible: root.radius > 0
        source: nextWallpaper
        maskSource: discMask
    }
}
