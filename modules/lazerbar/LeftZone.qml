import QtQuick
import "../../services" as Services

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
            titleText: Services.Tr.q("sidebar.settings")
            subtitleText: Services.Tr.q("sidebar.settings.subtitle")
            isActive: root.settingsActive
            onClicked: root.settingsRequested()
        }
        IconButton { source: "icons/home.svg"; accessibleName: Services.Tr.q("sidebar.home") }
        BarBoundaryStrip { anchors.verticalCenter: parent.verticalCenter }
        ModeSelector {
            id: modes
            osuSource: "icons/mode-osu.svg"
            taikoSource: "icons/mode-taiko.svg"
            catchSource: "icons/mode-catch.svg"
            maniaSource: "icons/mode-mania.svg"
        }
    }
}
