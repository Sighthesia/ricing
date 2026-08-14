import QtQuick

// Group system controls with the game-mode selector.
Item {
    id: root
    property alias selectedMode: modes.selectedMode
    implicitWidth: row.implicitWidth
    implicitHeight: LazerTheme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        IconButton { source: "icons/settings.svg"; accessibleName: "Settings" }
        IconButton { source: "icons/home.svg"; accessibleName: "Home" }
        Rectangle { width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: LazerTheme.divider }
        ModeSelector {
            id: modes
            osuSource: "icons/mode-osu.svg"
            taikoSource: "icons/mode-taiko.svg"
            catchSource: "icons/mode-catch.svg"
            maniaSource: "icons/mode-mania.svg"
        }
    }
}
