import QtQuick

// Keep identity, time, uptime, and notification state readable together.
Item {
    id: root
    property string username: "Sighthesia"
    property url avatarSource
    property bool notificationsActive: false
    implicitWidth: row.implicitWidth
    implicitHeight: LazerTheme.barHeight
    function activateNotification() { notificationsActive = !notificationsActive }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        UserProfile { username: root.username; avatarSource: root.avatarSource }
        Rectangle { width: 1; height: 24; anchors.verticalCenter: parent.verticalCenter; color: LazerTheme.divider }
        ClockWidget { anchors.verticalCenter: parent.verticalCenter }
        IconButton { source: "icons/bell.svg"; accessibleName: "Notifications"; active: root.notificationsActive; activeColor: LazerTheme.osuPink; onClicked: root.activateNotification() }
    }
}
