import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Launcher results viewport with delegate rendering and row interactions.
Item {
    id: root

    property alias model: resultList.model
    property int selectedIndex: -1

    signal selectRequested(int index)
    signal activateRequested(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true

    function runEnter(): void {
    }

    function runExit(): void {
    }

    ListView {
        id: resultList
        anchors.fill: parent
        clip: true
        cacheBuffer: 0

        delegate: Item {
            id: _item

            required property int index
            required property string name
            required property string description
            required property string icon

            width: resultList.width
            height: 52

            function runExit(): void {
            }

            Rectangle {
                anchors.fill: parent
                color: root.selectedIndex === _item.index
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Image {
                        source: "image://icon/" + (_item.icon || "application-x-executable")
                        width: 24
                        height: 24
                        sourceSize: Qt.size(24, 24)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: _item.name
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeBody
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: _item.description
                            color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: _item.description !== ""
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectRequested(_item.index)
                    onClicked: root.activateRequested(_item.index)
                }
            }
        }
    }

    function positionSelection(index): void {
        if (index < 0 || index >= resultList.count) return;
        resultList.positionViewAtIndex(index, ListView.Contain);
    }

    function delegateAtIndex(index): var {
        return resultList.itemAtIndex(index);
    }
}
