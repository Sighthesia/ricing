import QtQuick
import qs.config
import qs.services
import "." as IslandCards

// Shared clock host wrapper for the compact media row.
Item {
    id: root

    required property date currentTime
    required property bool hasPendingEvents
    property bool showMedia: SettingsService.data.superIsland.showMedia !== false

    implicitWidth: _clock.implicitWidth
    implicitHeight: _clock.implicitHeight

    // Compact row reuses the idle clock card directly so media stays on one owner.
    IslandCards.IslandIdleClockCard {
        id: _clock

        anchors.centerIn: parent
        currentTime: root.currentTime
        hasPendingEvents: root.hasPendingEvents
        showMedia: root.showMedia
        cardHeight: Theme.barWidget.pillHeight
    }
}
