pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "WallpaperReveal.js" as RevealLogic

// Reveal a wallpaper through a circle that grows from the point the user
// triggered the switch, so the new wallpaper appears to spread out of the click.
//
// Structure follows the DymicShell background window: the next wallpaper is a
// hidden image, a full-screen mask container holds the circle, and an
// OpacityMask item paints the result. Three details are load-bearing:
//   * `asynchronous: false` on the private image — the reveal must never start
//     before the pixels exist. A full-screen wallpaper is far larger than
//     QPixmapCache's 10 MB limit, so an async reload always re-decodes from disk
//     and flashes.
//   * the mask container fills the surface with `layer.smooth`, so the mask is
//     sampled at screen resolution instead of being stretched into an ellipse.
//   * `sourceItem` — the host may lend an image it already owns and already
//     decoded (WallpaperBackground lends its incoming slot). The mask then
//     samples that item and the private image stays empty, so a wallpaper is
//     decoded exactly once per switch and the reveal ends by promoting the very
//     pixels it was showing instead of assigning the same source again.
//
// QtQuick.Shapes cannot be used for the circle (its antialiased edges pick up a
// 1px white ring), ShaderEffect cannot be used either (Qt 6.11 only accepts
// precompiled .qsb shaders), and MultiEffect's mask pass drops the source.
Item {
    id: root

    // Incoming wallpaper path, for a host that has no decoded slot to lend. The
    // host clears it once the reveal is handed over. Ignored while `sourceItem`
    // is set, because then the host owns the source.
    property string source: ""
    // A wallpaper image the host already owns and already decoded, lent to the
    // mask so a switch never decodes the same wallpaper twice. It must be a
    // sibling in the same scene graph, kept unpainted (the mask samples it into
    // a texture) and never assigned a source by this component.
    property Item sourceItem: null
    // Boot can decode off the GUI path before the reveal starts; live swaps keep
    // this false so their synchronous handover contract remains unchanged. Only
    // applies to the private image; a lent slot is decoded by its own host.
    property bool asynchronous: false
    // Circle centre, in this item's coordinates.
    property point origin: Qt.point(0, 0)
    // Current circle radius in pixels; 0 means nothing is revealed.
    property real radius: 0
    // Radius that covers the whole surface from `origin`.
    readonly property real coverRadius: RevealLogic.coverRadius(root.origin.x, root.origin.y, root.width, root.height)
    // Whatever the mask samples: the host's slot when it lends one, otherwise
    // the private image. `var` because the private image is what makes the
    // fallback type-safe, and the contract is the `status` field either way.
    readonly property var effectiveSourceItem: root.sourceItem ? root.sourceItem : nextWallpaper
    // A decoded incoming wallpaper is what the host waits for before growing.
    readonly property bool imageReady: root.effectiveSourceItem
        && root.effectiveSourceItem.status === Image.Ready
    readonly property bool imageFailed: root.effectiveSourceItem
        && root.effectiveSourceItem.status === Image.Error

    // Incoming wallpaper, decoded offstage and never painted directly: the mask
    // samples it into a texture instead. Empty whenever the host lends a slot,
    // so the wallpaper is decoded exactly once per switch.
    Image {
        id: nextWallpaper
        anchors.fill: parent
        source: root.sourceItem ? "" : root.source
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
        source: root.effectiveSourceItem
        maskSource: discMask
    }
}
