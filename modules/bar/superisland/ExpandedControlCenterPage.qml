import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "." as SuperIslandParts

// SuperIsland control center page with calendar, live system metrics, and media controls.
Item {
    id: root

    function pageActivated() {
        _pageStagger.clear()
        _pageStagger.registerItem(_calendarCard, 0, 1)
        _pageStagger.registerItem(_resourceCard, 1, 1)
        _pageStagger.registerItem(_mediaCard, 2, 1)
        _pageStagger.runEnter()
        _mediaContent.pageActivated()
    }

    function pageDeactivated() {
        _mediaContent.pageDeactivated()
        _pageStagger.runExit()
    }

    function pageExitDuration() {
        return SettingsService.data.animation.staggerExitDuration
            + SettingsService.data.animation.staggerExitStep * 2
    }

    BarComponents.StaggerOrchestrator {
        id: _pageStagger
    }

    GridLayout {
        anchors.fill: parent
        columns: 3
        columnSpacing: 12
        rowSpacing: 12

        BarComponents.StaggerItem {
            id: _calendarCard
            Layout.columnSpan: 2
            Layout.rowSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: _calendarContent.implicitHeight

            SuperIslandParts.ExpandedControlCenterCalendarCard {
                id: _calendarContent
                anchors.fill: parent
            }
        }

        BarComponents.StaggerItem {
            id: _resourceCard
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            implicitHeight: _resourceContent.implicitHeight

            SuperIslandParts.ExpandedControlCenterResourceCard {
                id: _resourceContent
                anchors.fill: parent
            }
        }

        BarComponents.StaggerItem {
            id: _mediaCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: _mediaContent.implicitHeight

            SuperIslandParts.ExpandedControlCenterMediaCard {
                id: _mediaContent
                anchors.fill: parent
            }
        }
    }
}
