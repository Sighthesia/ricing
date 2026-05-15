import QtQuick
import "../../services" as Services

Item {
    anchors.fill: parent

    ListView {
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        spacing: 4
        model: Services.ClipboardService.items
        delegate: ClipboardDelegate {}
    }

    Component.onCompleted: Services.ClipboardService.list()
}
