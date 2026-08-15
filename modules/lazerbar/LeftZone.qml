import QtQuick

// Group system controls with the game-mode selector.
Item {
    id: root
    property alias selectedMode: modes.selectedMode
    property bool settingsActive: false
    property alias settingsButtonItem: settingsButton
    signal settingsRequested
    implicitWidth: row.implicitWidth
    implicitHeight: LazerTheme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        OsuTopBarButton {
            id: settingsButton
            iconSource: "icons/settings.svg"
            titleText: "设置"
            subtitleText: "个性化 Afloat"
            isActive: root.settingsActive
            onClicked: root.settingsRequested()
        }
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
