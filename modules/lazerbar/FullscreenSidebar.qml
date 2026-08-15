import QtQuick

// Keep page-local navigation in a flat palette-aware osu sidebar.
Rectangle {
    id: root
    property var entries: []
    property string selected: ""
    property var palette: ({})
    property real railWidth: 220
    signal selectedChangedByUser(string value)

    width: railWidth
    color: palette.sidebar || "#312541"

    ListView {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        model: root.entries
        spacing: 2
        clip: true
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: 42
            color: root.selected === modelData.id ? root.palette.accent || "#D8A8EF"
                    : itemHover.hovered ? "#18FFFFFF" : "transparent"
            Text {
                anchors.left: parent.left; anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: root.selected === modelData.id ? root.palette.body || "#222" : root.palette.text || "white"
                font.pixelSize: 13; font.bold: root.selected === modelData.id
            }
            HoverHandler { id: itemHover }
            TapHandler { onTapped: root.selectedChangedByUser(modelData.id) }
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }
}
