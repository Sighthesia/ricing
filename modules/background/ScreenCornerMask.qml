import QtQuick
import QtQuick.Shapes

// Render a single faux display corner so the host can place it per edge.
Item {
    id: root

    property real angle: 0
    property color fillColor: "black"

    rotation: angle
    transformOrigin: Item.Center

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            fillColor: root.fillColor
            strokeWidth: 0
            startX: 0
            startY: 0

            PathLine {
                x: root.width
                y: 0
            }

            PathArc {
                x: 0
                y: root.height
                radiusX: root.width
                radiusY: root.height
                direction: PathArc.Counterclockwise
            }

            PathLine {
                x: 0
                y: 0
            }
        }
    }
}
