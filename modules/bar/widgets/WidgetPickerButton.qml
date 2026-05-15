import QtQuick
import "../../../services" as Services

// Toggle layout editing mode and widget picker from the bar.
Item {
    id: root

    implicitWidth: 26
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight

    // Visual indicator: icon changes based on settings mode state.
    Text {
        anchors.centerIn: parent
        text: Services.BarLayoutService.settingsMode ? "\u2715" : "+"
        color: Services.BarLayoutService.settingsMode ? "#ff8888" : "white"
        font.pixelSize: 18

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // Toggle settings mode on click; if entering, also open picker.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Services.BarLayoutService.settingsMode) {
                Services.BarLayoutService.exitSettingsMode()
            } else {
                Services.BarLayoutService.openWidgetPicker("center")
            }
        }
    }

}
