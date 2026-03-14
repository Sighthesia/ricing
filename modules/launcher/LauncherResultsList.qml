import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.modules.bar

// Launcher results viewport with delegate rendering and row interactions.
StaggerItem {
    id: root

    property alias model: resultList.model
    property int selectedIndex: -1

    signal selectRequested(int index)
    signal activateRequested(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true
    exitDelay: 0

    ListView {
        id: resultList
        anchors.fill: parent
        clip: true
        cacheBuffer: 0

        delegate: StaggerItem {
            id: _item

            required property int index
            required property string name
            required property string description
            required property string icon

            delay:  SettingsService.data.animation.staggerLevel1BaseDelay
                    + (index % 8) * 25
            width: resultList.width
            height: 52

            Component.onCompleted: runEnter()

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
