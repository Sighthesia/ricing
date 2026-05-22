import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../../services" as Services

// System tray icon row with click support.
Item {
    id: root

    implicitWidth: trayRow.implicitWidth + 16
    implicitHeight: 30

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items

            // Individual tray icon
            Item {
                width: 22
                height: 22
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: modelData.icon
                    sourceSize: Qt.size(20, 20)
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.LeftButton)
                            modelData.activate()
                        else if (event.button === Qt.RightButton)
                            modelData.activate()
                    }
                }
            }
        }
    }
}
