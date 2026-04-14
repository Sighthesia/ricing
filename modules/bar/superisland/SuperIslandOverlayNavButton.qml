import QtQuick
import QtQuick.Layouts
import qs.config
import ".." as BarComponents

// Segmented-control segment used by the expanded SuperIsland overlay top bar.
Rectangle {
    id: root

    property string label: ""
    property string iconGlyph: ""
    property bool selected: false
    property bool firstSegment: false
    property bool lastSegment: false

    signal pressed()

    implicitWidth: ThemeCards.overlayNavSegmentMinWidth
    implicitHeight: ThemeCards.overlayNavSegmentHeight
    radius: 0
    color: selected
        ? Colors.highlight
        : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.12)
    border.color: "transparent"
    border.width: 0

    topLeftRadius: firstSegment ? ThemeCards.overlayNavRadius : 0
    bottomLeftRadius: firstSegment ? ThemeCards.overlayNavRadius : 0
    topRightRadius: lastSegment ? ThemeCards.overlayNavRadius : 0
    bottomRightRadius: lastSegment ? ThemeCards.overlayNavRadius : 0

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
        radius: firstSegment || lastSegment ? ThemeCards.overlayNavRadius : 0
        hovered: _area.containsMouse && !root.selected
        highlightColor: Colors.highlight
        highlightOpacity: 0.12
    }

    BarComponents.ClickRipple {
        id: _ripple
        anchors.fill: parent
        radius: firstSegment || lastSegment ? ThemeCards.overlayNavRadius : 0
        rippleColor: Colors.highlight
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: ThemeCards.overlayNavPaddingH
        anchors.rightMargin: ThemeCards.overlayNavPaddingH
        spacing: ThemeCards.overlayNavSpacing

        Text {
            text: root.iconGlyph
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall - 1
            color: root.selected ? Colors.background : Colors.textMuted
        }

        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 2
            font.weight: root.selected ? Font.Medium : Font.Normal
            color: root.selected ? Colors.background : Colors.textMuted
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
