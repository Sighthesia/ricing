import QtQuick
import "../../../services" as Services

// Present the widget picker trigger as content inside the shared right dock zone.
Item {
    id: root

    implicitWidth: 26
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight

    // Keep the add action centered in the dock zone body.
    Text {
        anchors.centerIn: parent
        text: "+"
        color: "white"
        font.pixelSize: 18
    }

    // Open the widget picker on click.
    MouseArea {
        anchors.fill: parent
        onClicked: Services.BarLayoutService.toggleWidgetPicker("center")
    }

}
