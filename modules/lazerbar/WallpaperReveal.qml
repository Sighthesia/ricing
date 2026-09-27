pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "WallpaperReveal.js" as RevealLogic

// Reveal a wallpaper through a circle that grows from the point the user
// triggered the switch, so the new wallpaper appears to spread out of the click.
//
// The circle is a plain rounded rectangle fed to an OpacityMask. The obvious
// alternatives do not work on this stack: QtQuick.Shapes leaves a 1px white ring
// on its antialiased edges, ShaderEffect only accepts precompiled .qsb shaders
// in Qt 6.11, and MultiEffect's mask pass drops the source entirely.
Item {
    id: root

    // Incoming wallpaper path. The host keeps it until the reveal settles.
    property string source: ""
    // Circle centre, in this item's coordinates.
    property point origin: Qt.point(0, 0)
    // Current circle radius in pixels; 0 means nothing is revealed.
    property real radius: 0
    // Radius that covers the whole surface from `origin`.
    readonly property real coverRadius: RevealLogic.coverRadius(root.origin.x, root.origin.y, root.width, root.height)
    // Only paint while a reveal is in flight, so an idle surface costs nothing.
    readonly property bool active: root.radius > 0 && root.source !== ""
    // The host waits for the incoming image before growing the circle.
    readonly property bool imageReady: incoming.status === Image.Ready
    readonly property bool imageFailed: incoming.status === Image.Error
    visible: root.active

    // Incoming wallpaper, shown only through the reveal circle.
    Image {
        id: incoming
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Keep the decoded pixmap in Qt's image cache. The host hands the
        // settled layer the same source right after the reveal, so a cache hit
        // makes that handover instant instead of decoding the wallpaper a
        // second time with a frame of bare background in between.
        cache: true
        layer.enabled: true
        layer.effect: OpacityMask {
            // The mask spans the whole surface so the circle keeps its position
            // while it grows, and it is declared inside the effect so it never
            // joins the scene as a white disc.
            maskSource: Item {
                width: root.width
                height: root.height
                Rectangle {
                    width: Math.max(0, root.radius) * 2
                    height: width
                    radius: width / 2
                    x: root.origin.x - width / 2
                    y: root.origin.y - height / 2
                    color: "white"
                }
            }
        }
    }
}
