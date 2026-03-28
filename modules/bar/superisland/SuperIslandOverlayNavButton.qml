import QtQuick
import QtQuick.Layouts
import qs.config
import ".." as BarComponents

// Navigation button used by the expanded SuperIsland overlay top bar.
Rectangle {
    id: root

    property string label: ""
    property string iconGlyph: ""
    property bool selected: false

    signal pressed()

    implicitWidth: 92
    implicitHeight: 30
    radius: Theme.cornerRadius - 2
    color: selected
        ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.18)
        : "transparent"
    border.color: selected
        ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.34)
        : "transparent"
    border.width: 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.highlightDuration
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.anim.highlightDuration
        }
    }

    BarComponents.HoverRevealHighlight {
        anchors.fill: parent
        radius: parent.radius
        hovered: _area.containsMouse && !root.selected
        highlightColor: Colors.surface
        highlightOpacity: 0.54
    }

    BarComponents.ClickRipple {
        id: _ripple
        anchors.fill: parent
        radius: parent.radius
        rippleColor: Colors.highlight
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 6

        Text {
            text: root.iconGlyph
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: root.selected ? Colors.highlight : Colors.textMuted
        }

        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: root.selected ? Font.Medium : Font.Normal
            color: root.selected ? Colors.text : Colors.textMuted
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: _area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            _ripple.triggerRipple(mouse.x, mouse.y)
            root.pressed()
        }
    }
}
