import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../../services" as Services

// System tray icon row with click support.
Item {
    id: root

    implicitWidth: trayRow.implicitWidth + 12
    implicitHeight: 26

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: SystemTray.items

            // Individual tray icon
            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: modelData.icon
                    sourceSize: Qt.size(18, 18)
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
