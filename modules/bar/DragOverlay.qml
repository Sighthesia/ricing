import QtQuick
import qs.config
import qs.services

Item {
    id: dragOverlay

    anchors.fill: parent
    visible: BarLayoutService.settingsMode
    z: 999

    // Dim background
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: BarLayoutService.settingsMode ? 0.15 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.exitDuration; easing.type: Easing.InExpo }
        }
    }

    // Drop zone indicators: three sections with dashed borders
    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.barPadding
        anchors.rightMargin: Theme.barPadding

        DropZone {
            id: leftZone
            zoneName: "left"
            width: parent.width / 3
            height: parent.height
        }

        DropZone {
            id: centerZone
            zoneName: "center"
            width: parent.width / 3
            height: parent.height
        }

        DropZone {
            id: rightZone
            zoneName: "right"
            width: parent.width / 3
            height: parent.height
        }
    }

    // Floating widget copies (created dynamically from layout model)
    Repeater {
        id: floatingWidgets
        model: BarLayoutService.settingsMode ? BarLayoutService.layoutModel.count : 0

        delegate: FloatingWidget {
            required property int index
            widgetId: BarLayoutService.layoutModel.get(index).id
            widgetSection: BarLayoutService.layoutModel.get(index).section
            widgetAlignment: BarLayoutService.layoutModel.get(index).alignment
            parentOverlay: dragOverlay
        }
    }

    // Hit-test: determine which zone a point falls in
    function hitTestZone(globalX) {
        let relX = globalX - dragOverlay.x;
        let thirdWidth = dragOverlay.width / 3;
        if (relX < thirdWidth) return "left";
        if (relX < thirdWidth * 2) return "center";
        return "right";
    }

    function highlightZone(zoneName) {
        leftZone.highlighted = (zoneName === "left");
        centerZone.highlighted = (zoneName === "center");
        rightZone.highlighted = (zoneName === "right");
    }

    function clearHighlights() {
        leftZone.highlighted = false;
        centerZone.highlighted = false;
        rightZone.highlighted = false;
    }
}
