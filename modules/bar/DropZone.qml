import QtQuick
import qs.config

Item {
    id: dropZone

    required property string zoneName
    property bool highlighted: false

    // Dashed border rectangle
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        color: "transparent"
        border.color: highlighted ? Palette.highlight : Palette.border
        border.width: 1
        radius: Theme.cornerRadius
        opacity: highlighted ? 0.8 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.anim.highlightDuration
            }
        }
    }

    // Zone label
    Text {
        anchors.centerIn: parent
        text: dropZone.zoneName
        font.family: Theme.fontFamily
        font.pixelSize: 10
        color: Palette.textMuted
        opacity: 0.5
    }
}
