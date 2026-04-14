import QtQuick
import qs.config
import qs.services

// Marks a bar section as an interactive drag target and picker anchor zone.
Item {
    id: dropZone

    required property string zoneName

    // Auto-highlight when a widget is dragged over this zone
    property bool highlighted: BarLayoutService.isDragging
        && BarLayoutService.dragHoverZone === zoneName

    // Extra highlight when widget picker is open for this zone
    property bool selected: BarLayoutService.widgetPickerOpen
        && BarLayoutService.widgetPickerTargetSection === zoneName

    // Zone indicator rectangle — full height, horizontal padding only so the
    // border matches widget height rather than being visually shorter.
    Rectangle {
        anchors.fill: parent

        radius: Theme.cornerRadius

        // Semi-transparent fill makes each zone visually distinct without
        // fully obscuring the widgets underneath in layout mode.
        color: selected
            ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
            : highlighted
                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.08)
                : "transparent"

        border.color: (selected || highlighted) ? Colors.highlight : Colors.border
        border.width: (selected || highlighted) ? 1 : 0

        opacity: selected ? 1.0 : highlighted ? 0.85 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    // Zone label — pinned to the bottom-center so it doesn't obscure widget
    // content which is typically vertically centered in the bar.
    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        text: dropZone.zoneName
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: selected ? Colors.highlight : Colors.textMuted
        opacity: selected ? 0.9 : highlighted ? 0.6 : 0.35

        Behavior on color {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    // Click to select this zone and open / toggle the widget picker.
    // DragOverlay sits at z:999, so this MouseArea captures events above
    // all widget-level MouseAreas without needing to block them in normal mode.
    MouseArea {
        anchors.fill: parent
        enabled: BarLayoutService.settingsMode
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (BarLayoutService.isDragging) return;

            BarLayoutService.toggleWidgetPickerForSection(dropZone.zoneName)
        }
    }
}
