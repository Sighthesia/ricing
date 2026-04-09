import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "." as SuperIslandParts

// SuperIsland control center page with calendar, system resources, and media controls.
Item {
    id: root

    implicitWidth: _contentGrid.implicitWidth
    implicitHeight: _contentGrid.implicitHeight

    function pageActivated() {
        _pageStagger.clear()
        _pageStagger.registerItem(_calendarCard, 0, 1)
        _pageStagger.registerItem(_utilityCard, 1, 1)
        _pageStagger.registerItem(_mediaCard, 2, 1)
        _pageStagger.runEnter()
        _mediaContent.pageActivated()
    }

    function pageDeactivated() {
        _mediaContent.pageDeactivated()
        _pageStagger.runExit()
    }

    function pageExitDuration() {
        return SettingsService.effectiveAnimation.staggerExitDuration
            + SettingsService.effectiveAnimation.staggerExitStep * 2
    }

    BarComponents.StaggerOrchestrator {
        id: _pageStagger
    }

    GridLayout {
        id: _contentGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        columns: 3
        columnSpacing: Math.round(12 * Theme.uiScale)
        rowSpacing: Math.round(12 * Theme.uiScale)

        BarComponents.StaggerItem {
            id: _calendarCard
            Layout.columnSpan: 2
            Layout.rowSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: _calendarContent.implicitWidth
            implicitHeight: _calendarContent.implicitHeight

            SuperIslandParts.ExpandedControlCenterCalendarCard {
                id: _calendarContent
                anchors.fill: parent
            }
        }

        BarComponents.StaggerItem {
            id: _utilityCard
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            implicitWidth: _utilityColumn.implicitWidth
            implicitHeight: _utilityColumn.implicitHeight

            ColumnLayout {
                id: _utilityColumn
                anchors.fill: parent
                spacing: Math.round(12 * Theme.uiScale)

                SuperIslandParts.ExpandedControlCenterResourceCard {
                    id: _resourceContent
                    Layout.fillWidth: true
                }

                SuperIslandParts.ExpandedControlCenterBreakCommandsCard {
                    id: _breakCommandContent
                    Layout.fillWidth: true
                }
            }
        }

        BarComponents.StaggerItem {
            id: _mediaCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: _mediaContent.implicitWidth
            implicitHeight: _mediaContent.implicitHeight

            SuperIslandParts.ExpandedControlCenterMediaCard {
                id: _mediaContent
                anchors.fill: parent
            }
        }
    }
}
