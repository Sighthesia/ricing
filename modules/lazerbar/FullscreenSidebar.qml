import QtQuick

// Give every route the same stable, independently scrollable navigation rail.
Rectangle {
    id: root
    property var entries: []
    property string selected: ""
    property int railWidth: 220
    signal selectedChangedByUser(string value)
    width: railWidth
    color: "#B914141A"

    ListView {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 5
        model: root.entries
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: 42
            radius: 8
            color: root.selected === modelData.id ? "#40EB1C60" : "transparent"
            Text { anchors.fill: parent; anchors.leftMargin: 14; verticalAlignment: Text.AlignVCenter; text: modelData.label; color: root.selected === modelData.id ? "white" : "#B8B4BC"; font.pixelSize: 13 }
            MouseArea { anchors.fill: parent; onClicked: root.selectedChangedByUser(modelData.id) }
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }
}
