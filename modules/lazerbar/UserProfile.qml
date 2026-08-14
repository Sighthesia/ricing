import QtQuick
import "LazerBarLogic.js" as Logic

// Keep profile geometry stable while avatar content loads or fails.
Item {
    id: root
    property string username: "Sighthesia"
    property url avatarSource
    readonly property string fallbackText: Logic.fallbackInitial(username)
    readonly property bool avatarReady: avatar.status === Image.Ready
    implicitWidth: row.implicitWidth
    implicitHeight: 32

    Row {
        id: row
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        Text { anchors.verticalCenter: parent.verticalCenter; text: root.username; color: LazerTheme.textPrimary; font.pixelSize: 13 }
        Rectangle {
            width: 32; height: 32; radius: 4; color: "#2D2A32"; clip: true
            border.width: 1
            border.color: "#1FFFFFFF"
            Text { anchors.centerIn: parent; text: root.fallbackText; color: LazerTheme.textPrimary; font.bold: true; opacity: root.avatarReady ? 0 : 1; Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } } }
            Image { id: avatar; anchors.fill: parent; source: root.avatarSource; fillMode: Image.PreserveAspectCrop; opacity: root.avatarReady ? 1 : 0; Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } } }
        }
    }
}
