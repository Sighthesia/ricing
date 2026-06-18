import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Simple placeholder detail page for calendar and weather until data sources are wired.
Item {
    id: root

    property string title: ""
    property string body: ""

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6

            Services.FluidText {
                text: root.title
                color: Services.Color.mOnSurface
                basePixelSize: 16
                font.bold: true
            }

            Services.FluidText {
                text: root.body
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 12
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }
    }
}
