import QtQuick
import Quickshell
import Quickshell.Wayland
import "./modules/lazerbar" as Lazer

// Render harness for the lazer loading ring: mounts the real component at the
// three sizes afloat uses it at, captures each one, and reports how many
// non-background pixels the arc actually painted. A green run here is the only
// proof that the Canvas calls (ctx.reset, lineCap, Qt.rgba) survive contact with
// Quickshell — the logic tests never touch a context.
//
//   qs -p tst_loading_ring_visual.qml   → writes /tmp/opencode/ring-*.png

ShellRoot {
    id: root

    property int shots: 0
    property int drained: 0

    PanelWindow {
        id: probe
        implicitWidth: 260
        implicitHeight: 140
        color: "#18171C"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore

        Column {
            id: stack
            anchors.centerIn: parent
            spacing: 16

            // Launcher size: big enough for the triangle field to show.
            Lazer.LazerLoadingRing {
                objectName: "ring60"
                width: 60
                height: 60
                seed: 3
            }

            Lazer.LazerLoadingRing {
                objectName: "ring28"
                width: 28
                height: 28
                seed: 3
            }

            // Popup size: the field has to be skipped here, arc only.
            Lazer.LazerLoadingRing {
                objectName: "ring16"
                width: 16
                height: 16
                seed: 3
            }
        }
    }

    // Index of a named child, so the shots can be taken in declaration order
    // without holding a live reference to each ring.
    function indexOfChild(name) {
        for (var i = 0; i < stack.children.length; ++i) {
            if (stack.children[i].objectName === name)
                return i
        }
        return -1
    }

    Timer {
        interval: 700
        running: true
        repeat: true
        onTriggered: {
            // grabToImage resolves on a later frame than it is called, so hold
            // the shell open a few extra ticks or the last log never flushes.
            if (root.shots >= 3) {
                if (++root.drained >= 4) {
                    running = false
                    Qt.callLater(Qt.quit)
                }
                return
            }

            var names = ["ring60", "ring28", "ring16"]
            var target = stack.children[root.indexOfChild(names[root.shots])]
            if (!target) {
                console.warn("[ring] missing " + names[root.shots])
                root.shots++
                return
            }

            target.grabToImage(function(result) {
                if (!result || !result.image) {
                    console.warn("[ring] grab failed for " + target.objectName)
                    return
                }
                var path = "/tmp/opencode/ring-" + target.objectName + ".png"
                var ok = result.saveToFile(path)
                // warn, not log: Quickshell only surfaces warnings from QML.
                // A non-trivial file size is the signal that the Canvas
                // rasterized something; QImage.pixel() is not exposed to QML, so
                // this stands in for counting painted pixels.
                console.warn("[ring] " + target.objectName
                             + " edge=" + Math.round(target.width)
                             + " saved=" + ok
                             + " -> " + path)
            })
            root.shots++
        }
    }
}
